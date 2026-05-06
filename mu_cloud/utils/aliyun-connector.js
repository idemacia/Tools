/**
 * 阿里云IoT平台连接器
 * 负责与阿里云IoT平台进行通信，封装核心API调用
 * 
 * 主要功能：
 * 1. 设备状态查询
 * 2. 设备控制指令下发
 * 3. 错误处理和日志记录
 * 
 * @module utils/aliyun-connector
 * @requires ./aliIot-sdk
 * @version 1.0.0
 * @since 2025-05-12
 */
const aliSdk = require("./aliIot-sdk.js")
const monitor = require("./monitor")

class AliyunConnector {
  /**
   * 创建阿里云IoT连接器实例
   * @param {Object} config 配置对象，包含:
   *   - {string} productKey 产品Key，阿里云IoT平台分配的产品唯一标识
   *   - {string} deviceName 设备名称，在阿里云IoT平台注册的设备名称
   *   - {string} [endpoint] 服务端点，格式如: "iot.cn-shanghai.aliyuncs.com"
   *   - {string} [ai] AccessKey ID，阿里云账号访问密钥ID
   *   - {string} [as] AccessKey Secret，阿里云账号访问密钥
   *   - {string} [apiVersion] API版本号，默认为"2018-01-20"
   * @throws {Error} 当缺少必要配置时抛出错误
   * @example
   * const connector = new AliyunConnector({
   *   productKey: 'your_product_key',
   *   deviceName: 'your_device_name',
   *   endpoint: 'https://iot.cn-shanghai.aliyuncs.com'
   * })
   * 
   * 初始化流程：
   * 1. 验证必要配置
   * 2. 保存配置
   * 3. 初始化SDK
   */
  constructor(config) {
    // 验证必要配置
    if (!config.productKey || !config.deviceName || !config.accessKeyId || !config.accessKeySecret || !config.endpoint) {
      throw new Error('缺少必要配置: productKey/deviceName/accessKeyId/accessKeySecret/endpoint')
    }
    
    this.config = {
      productKey: config.productKey,
      deviceName: config.deviceName,
      ai: config.accessKeyId,
      as: config.accessKeySecret,
      endpoint: config.endpoint,
      apiVersion: config.apiVersion || '2018-01-20',
      iotInstanceId: config.iotInstanceId || undefined
    }
    this.initSDK()
  }

  initSDK() {
    // console.log('初始化阿里云IoT SDK，配置:', this.config)
    try {
      this.sdk = aliSdk
      if (!this.sdk || !this.sdk.request) {
        throw new Error('阿里云IoT SDK初始化失败')
      }
      // console.log('阿里云IoT SDK初始化成功')
    } catch (err) {
      // console.error('SDK初始化错误:', err)
      throw err
    }
  }

  /**
   * 查询设备属性状态
   * 从阿里云IoT平台获取设备的最新属性数据
   * 
   * @async
   * @method
   * @param {string} deviceId 设备ID，对应阿里云IoT平台的设备名称
   * @returns {Promise<Object>} 返回设备属性数据，包含:
   *   - {Array} Data.List.PropertyStatusInfo 属性状态数组
   *   - {string} Data.List.PropertyStatusInfo[].Identifier 属性标识符
   *   - {string} Data.List.PropertyStatusInfo[].Value 属性值
   * @throws {Error} 当查询失败或数据无效时抛出错误
   * @example
   * try {
   *   const data = await connector.queryDeviceData('demo01')
   *   // console.log('设备数据:', data.Data.List.PropertyStatusInfo)
   * } catch (err) {
   *   // console.error('查询失败:', err.message)
   * }
   * 
   * 请求流程：
   * 1. 构建查询参数
   * 2. 调用阿里云API
   * 3. 验证响应数据
   * 4. 返回有效数据
   */
  async queryDeviceData(deviceId) {
    // console.log('查询设备数据，设备ID:', deviceId)
    const params = {
      Action: "QueryDevicePropertyStatus",
      ProductKey: this.config.productKey,
      DeviceName: deviceId
    }

    try {
      const startTime = Date.now()
      const res = await new Promise((resolve, reject) => {
        this.sdk.request(this.config, params, {method: "POST"}, 
          (res) => {
            const cost = Date.now() - startTime
      try {
        monitor.trackPerformance('aliyun_api_request', cost, {
          api: params.Action,
          status: 'success'
        })
      } catch (err) {
        // console.warn('性能监控失败:', err)
      }
            resolve(res)
          },
          (err) => {
            const cost = Date.now() - startTime
            monitor.trackPerformance('aliyun_api_request', cost, {
              api: params.Action,
              status: 'failed'
            })
            reject(err)
          })
      })
      // console.log(`请求成功，耗时: ${Date.now() - startTime}ms`, res)
      
      // 验证响应数据
      if (!res || !res.data) {
        throw new Error('无效的响应数据')
      }
      if (res.data.Code) {
        throw new Error(res.data.ErrorMessage || '阿里云API返回错误')
      }
      
      return res
    } catch (err) {
      // console.error('查询设备数据失败:', err, '请求参数:', params)
      throw new Error(`查询设备失败: ${err.message}`)
    }
  }

  /**
   * 控制设备执行服务
   * 向阿里云IoT平台发送控制指令
   * 
   * @async
   * @method
   * @param {string} deviceId 设备ID，对应阿里云IoT平台的设备名称
   * @param {Object} serviceData 控制指令对象，包含:
   *   - {number} ledNo LED编号(1-4)
   *   - {boolean|number} ledswitch 开关状态(true/1或false/0)
   *   - {number} brightness 亮度值(0-100)
   *   - {Array<number>} rgbdata RGB颜色值数组([R,G,B])
   * @returns {Promise<Object>} 返回控制结果，包含:
   *   - {string} RequestId 请求ID
   *   - {boolean} Success 是否成功
   * @throws {Error} 当控制失败或数据无效时抛出错误
   * @example
   * try {
   *   const result = await connector.controlDevice('demo01', {
   *     ledNo: 1,
   *     ledswitch: true,
   *     brightness: 80
   *   })
   *   console.log('控制结果:', result.Success)
   * } catch (err) {
   *   console.error('控制失败:', err.message)
   * }
   * 
   * 请求流程：
   * 1. 构建控制参数
   * 2. 调用阿里云API
   * 3. 验证响应数据
   * 4. 返回控制结果
   */
  async controlDevice(deviceId, serviceData) {
    return this.invokeService(deviceId, serviceData, 'set')
  }

  /**
   * 使用 SetDeviceProperty 设置设备属性（推荐，兼容不支持 InvokeThingService「set」的实例）
   * @param {string} deviceId DeviceName
   * @param {Object} items 物模型属性键值，如 { power: 1, brightness: 50 }
   * @see https://help.aliyun.com/zh/iot/developer-reference/api-ae0d2f
   */
  async setDeviceProperty(deviceId, items) {
    const params = {
      Action: 'SetDeviceProperty',
      ProductKey: this.config.productKey,
      DeviceName: deviceId,
      Items: typeof items === 'string' ? items : JSON.stringify(items)
    }
    if (this.config.iotInstanceId) {
      params.IotInstanceId = this.config.iotInstanceId
    }

    try {
      const startTime = Date.now()
      const res = await new Promise((resolve, reject) => {
        this.sdk.request(this.config, params, { method: 'POST' },
          (res) => {
            monitor.trackPerformance('aliyun_api_request', Date.now() - startTime, {
              api: params.Action,
              status: 'success'
            })
            resolve(res)
          },
          (err) => {
            monitor.trackPerformance('aliyun_api_request', Date.now() - startTime, {
              api: params.Action,
              status: 'failed'
            })
            reject(err)
          })
      })

      if (!res || !res.data) {
        throw new Error('无效的响应数据')
      }
      if (res.data.Code) {
        throw new Error(res.data.ErrorMessage || '设置设备属性失败')
      }

      return res
    } catch (err) {
      console.error('设置设备属性失败:', err, '请求参数:', params)
      throw new Error(`设置设备属性失败: ${err.message}`)
    }
  }

  /**
   * 调用设备服务（通用方法，可指定 Identifier）
   * @param {string} deviceId 设备ID
   * @param {Object} serviceData 服务入参
   * @param {string} [identifier='set'] 服务标识符，标准物模型属性设置为 set
   */
  async invokeService(deviceId, serviceData, identifier = 'set') {
    const params = {
      Action: "InvokeThingService",
      ProductKey: this.config.productKey,
      DeviceName: deviceId,
      Identifier: identifier,
      Args: JSON.stringify(serviceData)
    }

    try {
      const startTime = Date.now()
      const res = await new Promise((resolve, reject) => {
        this.sdk.request(this.config, params, {method: "POST"},
          (res) => {
            const cost = Date.now() - startTime
            monitor.trackPerformance('aliyun_api_request', cost, {
              api: params.Action,
              status: 'success'
            })
            resolve(res)
          },
          (err) => {
            const cost = Date.now() - startTime
            monitor.trackPerformance('aliyun_api_request', cost, {
              api: params.Action,
              status: 'failed'
            })
            reject(err)
          })
      })
      
      if (!res || !res.data) {
        throw new Error('无效的响应数据')
      }
      if (res.data.Code) {
        throw new Error(res.data.ErrorMessage || '控制设备失败')
      }
      
      return res
    } catch (err) {
      console.error('控制设备失败:', err, '请求参数:', params)
      throw new Error(`控制设备失败: ${err.message}`)
    }
  }

  /**
   * 查询设备状态
   * 从阿里云IoT平台获取设备的在线状态
   * 
   * @async
   * @method
   * @param {string} deviceId 设备ID，对应阿里云IoT平台的设备名称
   * @returns {Promise<Object>} 返回设备状态数据，包含:
   *   - {string} Data.Status 设备状态(ONLINE/OFFLINE)
   *   - {string} Data.LastOnlineTime 最后在线时间
   * @throws {Error} 当查询失败或数据无效时抛出错误
   * @example
   * try {
   *   const status = await connector.queryDeviceStatus('demo01')
   *   console.log('设备状态:', status.Data.Status)
   * } catch (err) {
   *   console.error('查询失败:', err.message)
   * }
   */
  async queryDeviceStatus(deviceId) {
    console.log('查询设备状态，设备ID:', deviceId)
    const params = {
      Action: "GetDeviceStatus",
      ProductKey: this.config.productKey,
      DeviceName: deviceId
    }

    try {
      const startTime = Date.now()
      const res = await new Promise((resolve, reject) => {
        this.sdk.request(this.config, params, {method: "POST"},
          (res) => {
            const cost = Date.now() - startTime
            monitor.trackPerformance('aliyun_api_request', cost, {
              api: params.Action,
              status: 'success'
            })
            resolve(res)
          },
          (err) => {
            const cost = Date.now() - startTime
            monitor.trackPerformance('aliyun_api_request', cost, {
              api: params.Action,
              status: 'failed'
            })
            reject(err)
          })
      })
      
      if (!res || !res.data) {
        throw new Error('无效的响应数据')
      }
      if (res.data.Code) {
        throw new Error(res.data.ErrorMessage || '查询设备状态失败')
      }
      
      return res
    } catch (err) {
      console.error('查询设备状态失败:', err, '请求参数:', params)
      throw new Error(`查询设备状态失败: ${err.message}`)
    }
  }
}

module.exports = {
  AliyunConnector: AliyunConnector
};
