// 智能插座控制页面 - 阿里云IoT版
const { deviceService } = require('../../services/device-service');
const iotConfig = require('../../config/iot-config');

Page({
  data: {
    device: {
      name: '智能插座',
      image: '/images/icons/socket_white.png',
      device_sn: ''
    },
    socket: {
      isOn: false,
      power: 0,
      voltage: 220.888,
      current: 10.543,
      energy: 10081,
      temperature: 25.45
    },
    timer: {
      isEnabled: false,
      startTime: '08:00',
      endTime: '18:00',
      days: [1, 2, 3, 4, 5]
    },
    connectionStatus: 'disconnected'
  },

  statusTimer: null,

  onLoad() {
    const deviceSn = iotConfig.deviceNameSocket || iotConfig.deviceName || wx.getStorageSync('deviceNameSocket');
    if (deviceSn) {
      this.setData({ 'device.device_sn': deviceSn, connectionStatus: 'connected' });
      this.fetchDeviceStatus();
      this.startStatusPolling();
    } else {
      this.setData({ connectionStatus: 'error' });
      wx.showToast({ title: '请在 config/iot-config.js 配置 deviceNameSocket', icon: 'none', duration: 3000 });
    }
  },

  onUnload() {
    if (this.statusTimer) clearInterval(this.statusTimer);
  },

  getDeviceId() {
    return this.data.device.device_sn;
  },

  toggleSocket() {
    const newState = !this.data.socket.isOn;
    this.setData({ 'socket.isOn': newState });
    const deviceId = this.getDeviceId();
    if (!deviceId) return;
    deviceService.toggleSmartPlug(deviceId, newState)
      .then(() => wx.showToast({ title: newState ? '已开启' : '已关闭', icon: 'success' }))
      .catch(err => {
        this.setData({ 'socket.isOn': !newState });
        wx.showToast({ title: err.message || '控制失败', icon: 'none' });
      });
  },

  toggleTimer(e) {
    const newState = e.detail.value;
    this.setData({ 'timer.isEnabled': newState });
    wx.showToast({ title: newState ? '定时已开启' : '定时已关闭', icon: 'success' });
  },

  setStartTime(e) {
    this.setData({ 'timer.startTime': e.detail.value });
  },

  setEndTime(e) {
    this.setData({ 'timer.endTime': e.detail.value });
  },

  selectDay(e) {
    const day = parseInt(e.currentTarget.dataset.day, 10);
    const days = [...this.data.timer.days];
    const idx = days.indexOf(day);
    if (idx > -1) days.splice(idx, 1);
    else days.push(day);
    this.setData({ 'timer.days': days });
  },

  fetchDeviceStatus() {
    const deviceId = this.getDeviceId();
    if (!deviceId) return;
    deviceService.getDeviceStatus(deviceId)
      .then(status => {
        this.setData({
          'socket.isOn': status.plugSwitch === 1 || status.PowerSwitch === 1,
          'socket.power': status.power ?? 0,
          'socket.voltage': status.voltage ?? 220,
          'socket.current': status.current ?? 0,
          'socket.energy': status.energy ?? 0,
          'socket.temperature': status.temperature ?? 25
        });
      })
      .catch(() => {});
  },

  startStatusPolling() {
    if (this.statusTimer) clearInterval(this.statusTimer);
    this.statusTimer = setInterval(() => this.fetchDeviceStatus(), 5000);
  }
});
