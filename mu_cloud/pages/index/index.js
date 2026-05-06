// 开源版首页 - 阿里云IoT设备入口
Page({
  data: {
    devices: [
      {
        id: 'smartled',
        name: '智能灯',
        icon: '/images/icons/samrt_led_white.png',
        path: '/pages/smartled/smartled'
      },
      {
        id: 'socket',
        name: '智能插座',
        icon: '/images/icons/socket_white.png',
        path: '/pages/socket/socket'
      }
    ]
  },

  onLoad() {
    // 检查阿里云配置
    this.checkConfig();
  },

  checkConfig() {
    try {
      const config = require('../../config/iot-config');
      const missing =
        !config.accessKeyId ||
        !config.accessKeySecret ||
        !config.productKey
      const stillTemplate =
        String(config.accessKeyId || '').startsWith('YOUR_') ||
        String(config.accessKeySecret || '').startsWith('YOUR_') ||
        String(config.productKey || '').startsWith('YOUR_')
      if (missing || stillTemplate) {
        wx.showModal({
          title: '配置提示',
          content:
            '请填写真实阿里云凭据：编辑 config/iot-config.js，或使用 wx.setStorageSync(\'iotConfig\', {...})。模板见 config/iot-config.js.example，详见 README.md',
          showCancel: false
        });
      }
    } catch (e) {
      // 忽略
    }
  },

  navigateToDevice(e) {
    const { path } = e.currentTarget.dataset;
    if (path) {
      wx.navigateTo({ url: path });
    }
  }
});
