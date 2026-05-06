// 阿里云IoT配置 - 请复制自 iot-config.js.example 或填入自己的值
// 切勿将含真实 AccessKey 的此文件提交到公开仓库；可用 wx.setStorageSync('iotConfig', {...}) 覆盖
const config = {
  productKey: wx.getStorageSync('productKey') || 'YOUR_PRODUCT_KEY',
  accessKeyId: wx.getStorageSync('accessKeyId') || 'YOUR_ACCESS_KEY_ID',
  accessKeySecret: wx.getStorageSync('accessKeySecret') || 'YOUR_ACCESS_KEY_SECRET',
  endpoint: wx.getStorageSync('endpoint') || 'https://iot.cn-shanghai.aliyuncs.com',
  deviceName: wx.getStorageSync('deviceName') || 'YOUR_DEVICE_NAME',
  deviceNameSmartled: wx.getStorageSync('deviceNameSmartled') || undefined,
  deviceNameSocket: wx.getStorageSync('deviceNameSocket') || undefined,
  smartledUseInvokeThingService: false,
  smartledThingServiceIdentifier: 'set',
  socketThingServiceIdentifier: 'led_ctrl_data',
  iotInstanceId: wx.getStorageSync('iotInstanceId') || undefined
}

try {
  const prodConfig = wx.getStorageSync('iotConfig')
  if (prodConfig) {
    Object.assign(config, prodConfig)
  }
} catch (err) {
  // 读取本地配置失败
}

module.exports = config
