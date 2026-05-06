/**
 * 设备服务模块
 * 负责与阿里云IoT平台交互，封装设备相关操作
 * 
 * 主要功能：
 * 1. 设备状态查询
 * 2. 设备控制指令下发
 * 3. 设备数据解析
 * 
 * @module services/device-service
 * @requires ../utils/aliyun-connector
 * @version 1.0.0
 * @since 2025-05-12
 */
const { AliyunConnector } = require("../utils/aliyun-connector")
const monitor = require("../utils/monitor")

class DeviceService {
  /**
   * 设备服务构造函数
   * @param {Object} [config={}] 配置对象
   * @param {string} [config.productKey] 产品Key，阿里云IoT平台分配的产品唯一标识
   * @param {string} [config.deviceName] 设备名称，在阿里云IoT平台注册的设备名称
   * @param {string} [config.endpoint] 服务端点，格式如: "iot.cn-shanghai.aliyuncs.com"
   * @param {string} [config.ai] AccessKey ID，阿里云账号访问密钥ID
   * @param {string} [config.as] AccessKey Secret，阿里云账号访问密钥
   * @param {string} [config.apiVersion] API版本号，默认为"2018-01-20"
   * @example
   * // 使用示例
   * const service = new DeviceService({
   *   productKey: 'your_product_key',
   *   deviceName: 'your_device_name'
   * })
   */
  constructor(config = {}) {
    // 从配置文件读取基础配置
    const baseConfig = require('../config/iot-config')
    
    // 合并配置（配置文件 > 构造函数参数）
    const finalConfig = {
      ...baseConfig,
      ...config,
      // 确保使用配置中的deviceName
      deviceName: baseConfig.deviceName || config.deviceName,
      // 兼容字段名差异
      ai: baseConfig.accessKeyId || config.ai,
      as: baseConfig.accessKeySecret || config.as
    }
    
    // 配置验证警告
    if (!finalConfig.accessKeyId || !finalConfig.accessKeySecret) {
      // console.warn('缺少AccessKey配置，将使用开发模式')
    }

    // 验证必要配置
    if (!finalConfig.productKey || !finalConfig.deviceName) {
      // console.warn('缺少必要配置，使用开发环境默认值')
    }

    // 创建阿里云连接器实例
    try {
      const { AliyunConnector } = require("../utils/aliyun-connector")
      this.connector = new AliyunConnector(finalConfig)
    } catch (err) {
      // console.error('创建连接器失败:', err)
      throw new Error('创建阿里云连接器失败: ' + err.message)
    }
  }

  /**
   * 获取设备状态
   * @async
   * @param {string} deviceId 设备ID，对应阿里云IoT平台的设备名称
   * @returns {Promise<Object>} 设备状态对象，包含:
   *   - {number} brightness 亮度值(0-100)
   *   - {boolean} onlinestate 在线状态
   *   - {number} temperature 温度值(℃)
   *   - {number} humidity 湿度值(%)
   * @throws {Error} 当设备ID为空或请求失败时抛出错误
   * @example
   * try {
   *   const status = await service.getDeviceStatus('demo')
   *   // console.log('当前温度:', status.temperature)
   * } catch (err) {
   *   // console.error('获取状态失败:', err.message)
   * }
   */
  async getDeviceStatus(deviceId) {
    if (!deviceId) {
      throw new Error('设备ID不能为空')
    }

    try {
      monitor.trackAction('get_device_status', {deviceId})
      // 调用连接器查询设备数据
      const res = await this.connector.queryDeviceData(deviceId)
      
      // 检查响应数据有效性
      if (!res || !res.data) {
        throw new Error('无效的响应数据')
      }

      // 检查错误码
      if (res.data.Code) {
        throw new Error(res.data.ErrorMessage || '阿里云API返回错误')
      }

      // 检查数据格式
      if (!res.data.Data || !res.data.Data.List || !Array.isArray(res.data.Data.List.PropertyStatusInfo)) {
        throw new Error('无效的数据格式')
      }
      
      // 解析并返回设备数据
      return this.parseDeviceData(res.data.Data.List.PropertyStatusInfo)
    } catch (err) {
      // console.error("获取设备状态失败 - 设备ID:", deviceId, "错误详情:", err)
      throw new Error(`获取设备状态失败: ${err.message}`)
    }
  }

  /**
   * 控制水泵开关
   * @async
   * @param {string} state 水泵状态('on'或'off')
   * @returns {Promise<boolean>} 返回控制结果，true表示成功
   * @throws {Error} 当控制失败时抛出错误
   */
  async controlPump(deviceId, pumpNo, pump_switchstate) {
    if (!deviceId) {
      throw new Error('设备ID不能为空')
    }
    if (pumpNo === undefined || pumpNo === null) {
      throw new Error('水泵编号不能为空')
    }
    
    // 使用属性设置方式控制水泵
    const params = {
      Action: "SetDeviceProperty",
      ProductKey: this.connector.config.productKey,
      DeviceName: deviceId,
      Items: JSON.stringify({
        pump_No: pumpNo,  // 使用传入的pumpNo参数
        pump_switchstate: pump_switchstate === 'on' ? 1 : 0
      })
    }

    // console.log('发送水泵属性设置命令:', params)
    
    try {
      const res = await new Promise((resolve, reject) => {
        this.connector.sdk.request(
          this.connector.config, 
          params, 
          {method: "POST"},
          (res) => resolve(res),
          (err) => reject(err)
        )
      })
      
      if (!res || !res.data) {
        throw new Error('无效的响应数据')
      }
      if (res.data.Code) {
        // console.error('阿里云API返回错误详情:', {
        //   Code: res.data.Code,
        //   Message: res.data.ErrorMessage,
        //   RequestId: res.data.RequestId
        // })
        throw new Error(`阿里云API错误: ${res.data.ErrorMessage || '设置设备属性失败'} (Code: ${res.data.Code})`)
      }
      return true
    } catch (err) {
      // console.error("设置水泵属性失败 - 详细错误:", {
      //   error: err,
      //   stack: err.stack,
      //   params: params,
      //   config: this.connector.config
      // })
      throw new Error(`设置水泵属性失败: ${err.message}`)
    }
  }

  /**
   * 控制灯光亮度
   * @async
   * @param {number} brightness 亮度值(0-100)
   * @returns {Promise<boolean>} 控制是否成功
   */
  async setLightBrightness(deviceId, brightness) {
    if (!deviceId) {
      throw new Error('设备ID不能为空')
    }
    if (brightness < 0 || brightness > 100) {
      throw new Error('亮度值必须在0-100之间')
    }
    return this.controlDevice(deviceId, {
      lightBrightness: brightness
    })
  }

  /**
   * 控制智能插座开关
   * @async
   * @param {boolean} state 开关状态
   * @returns {Promise<boolean>} 控制是否成功
   */
  async toggleSmartPlug(deviceId, state) {
    if (!deviceId) {
      throw new Error('设备ID不能为空')
    }
    return this.controlDevice(deviceId, {
      plugSwitch: state ? 1 : 0
    })
  }

  /**
   * 调用设备服务（通用方法，支持自定义 Identifier）
   * @async
   * @param {string} deviceId 设备ID
   * @param {Object} args 服务入参
   * @param {string} [identifier='set'] 服务标识符，与阿里云物模型 TSL 一致
   * @returns {Promise<boolean>}
   */
  async invokeService(deviceId, args, identifier = 'set') {
    if (!deviceId || !args) {
      throw new Error('参数不能为空')
    }
    try {
      monitor.trackAction('invoke_service', { deviceId, identifier })
      const res = await this.connector.invokeService(deviceId, args, identifier)
      if (!res || !res.data) throw new Error('无效的响应数据')
      if (res.data.Code) throw new Error(res.data.ErrorMessage || '调用服务失败')
      return true
    } catch (err) {
      throw new Error(`调用服务失败: ${err.message}`)
    }
  }

  /**
   * 控制设备
   * @async
   * @param {string} deviceId 设备ID，对应阿里云IoT平台的设备名称
   * @param {Object} command 控制命令对象，包含:
   *   - {number} ledNo LED编号(1-4)
   *   - {boolean|number} ledswitch 开关状态(true/1或false/0)
   *   - {number} brightness 亮度值(0-100)
   *   - {Array<number>} rgbdata RGB颜色值数组([R,G,B])
   *   - {number} pumpSwitch 水泵开关状态(1/0)
   * @returns {Promise<boolean>} 返回控制结果，true表示成功
   * @throws {Error} 当参数无效或控制失败时抛出错误
   * @example
   * try {
   *   const result = await service.controlDevice('demo', {
   *     ledNo: 1,
   *     ledswitch: true,
   *     brightness: 80
   *   })
   *   // console.log('控制结果:', result)
   * } catch (err) {
   *   // console.error('控制失败:', err.message)
   * }
   */
  async controlDevice(deviceId, command) {
    if (!deviceId || !command) {
      throw new Error('参数不能为空')
    }

    const iotConfig = require('../config/iot-config')
    const payload = this._resolveControlPayload(command, iotConfig)

    try {
      monitor.trackAction('control_device', {
        deviceId,
        command: JSON.stringify(command),
        payload: JSON.stringify(payload)
      })

      let res
      if (payload.mode === 'setProperty') {
        res = await this.connector.setDeviceProperty(deviceId, payload.items)
      } else {
        res = await this.connector.invokeService(deviceId, payload.args, payload.identifier)
      }

      if (!res || !res.data) {
        throw new Error('无效的响应数据')
      }

      if (res.data.Code) {
        throw new Error(res.data.ErrorMessage || '控制设备失败')
      }

      return true
    } catch (err) {
      throw new Error(`控制设备失败: ${err.message}`)
    }
  }

  /**
   * 根据命令字段区分插座 / 智能灯，并映射到物模型 TSL
   * 智能灯：默认用 SetDeviceProperty（多数实例不支持 InvokeThingService 的 set 服务）
   * 可选 smartledUseInvokeThingService: true 时仍走 InvokeThingService
   */
  _resolveControlPayload(command, iotConfig) {
    const isSocket =
      command.plugSwitch !== undefined ||
      command.PowerSwitch !== undefined

    if (isSocket) {
      const args = { ...command }
      if (command.PowerSwitch !== undefined && command.plugSwitch === undefined) {
        args.plugSwitch = command.PowerSwitch
      }
      const identifier = iotConfig.socketThingServiceIdentifier || 'led_ctrl_data'
      return { mode: 'invoke', args, identifier }
    }

    const items = {}
    if (command.ledswitch !== undefined) {
      items.power = command.ledswitch === 1 || command.ledswitch === true ? 1 : 0
    }
    if (command.lightBrightness !== undefined) {
      items.brightness = Number(command.lightBrightness)
    }
    if (command.hue !== undefined) {
      items.hue = Number(command.hue)
    }
    if (command.saturation !== undefined) {
      items.saturation = Number(command.saturation)
    }
    if (command.temperature !== undefined) {
      items.temperature = Number(command.temperature)
    }

    const formatted = this._formatSmartLedPropertyItems(items)

    if (iotConfig.smartledUseInvokeThingService) {
      const identifier = iotConfig.smartledThingServiceIdentifier || 'set'
      return { mode: 'invoke', args: formatted, identifier }
    }

    return { mode: 'setProperty', items: formatted }
  }

  /**
   * 阿里云要求 float/double 类型属性在 Items 中至少带一位小数（如 10.0）
   */
  _formatSmartLedPropertyItems(items) {
    const out = { ...items }
    if (out.hue !== undefined) {
      out.hue = Number(Number(out.hue).toFixed(1))
    }
    if (out.saturation !== undefined) {
      out.saturation = Number(Number(out.saturation).toFixed(1))
    }
    return out
  }

  /**
   * 解析设备数据
   * @param {Array} propertyInfos 原始属性信息数组
   * @return {Object} 返回按标识符组织的属性值对象
   */
  parseDeviceData(propertyInfos) {
    if (!Array.isArray(propertyInfos)) {
      return {}
    }

    const boolIds = new Set(['power', 'online_status'])
    const numIds = new Set(['brightness', 'hue', 'saturation', 'temperature'])

    const result = {}
    propertyInfos.forEach(item => {
      if (!item || !item.Identifier) return
      let val = item.Value !== undefined ? item.Value : null
      const id = item.Identifier

      if (val === null || val === undefined) {
        result[id] = null
        return
      }
      if (boolIds.has(id)) {
        result[id] = val === true || val === 'true' || val === 1 || val === '1'
        return
      }
      if (numIds.has(id)) {
        const n = Number(val)
        result[id] = Number.isNaN(n) ? val : n
        return
      }
      result[id] = val
    })
    return result
  }

  /**
   * 测试设备服务连接
   * @async
   * @returns {Promise<boolean>} 返回连接测试结果
   * @throws {Error} 当连接测试失败时抛出错误
   */
  async testConnection() {
    try {
      // 简单的配置验证作为连接测试
      if (!this.connector || !this.connector.config) {
        throw new Error('连接器未正确初始化')
      }
      
      const requiredConfig = ['productKey', 'deviceName', 'endpoint', 'ai', 'as']
      const missingConfig = requiredConfig.filter(key => !this.connector.config[key])
      
      if (missingConfig.length > 0) {
        throw new Error(`缺少必要配置: ${missingConfig.join(', ')}`)
      }
      
      return true
    } catch (err) {
      // console.error('连接测试失败:', err)
      throw new Error(`连接测试失败: ${err.message}`)
    }
  }

  /**
   * 检查设备在线状态
   * @async
   * @param {string} deviceId 设备ID
   * @returns {Promise<boolean>} 设备是否在线
   * @throws {Error} 当检查失败时抛出错误
   */
  async checkDeviceOnline(deviceId) {
    if (!deviceId) {
      throw new Error('设备ID不能为空')
    }

    try {
      monitor.trackAction('check_device_online', {deviceId})
      // 调用连接器查询设备状态
      if (!this.connector || typeof this.connector.queryDeviceStatus !== 'function') {
        throw new Error('连接器未正确初始化或缺少queryDeviceStatus方法')
      }
      const res = await this.connector.queryDeviceStatus(deviceId)
      
      // 检查响应数据有效性
      if (!res || !res.data) {
        throw new Error('无效的响应数据')
      }

      // 检查错误码
      if (res.data.Code) {
        throw new Error(res.data.ErrorMessage || '阿里云API返回错误')
      }

      // 返回设备在线状态
      return res.data.Data && res.data.Data.Status === 'ONLINE'
    } catch (err) {
      // console.error("检查设备在线状态失败 - 设备ID:", deviceId, "错误详情:", err)
      throw new Error(`检查设备在线状态失败: ${err.message}`)
    }
  }
}

// 导出类和实例
const deviceService = new DeviceService()
// console.log('DeviceService实例创建成功:', !!deviceService)
// console.log('testConnection方法存在:', typeof deviceService.testConnection === 'function')

module.exports = {
  DeviceService,
  deviceService
}
