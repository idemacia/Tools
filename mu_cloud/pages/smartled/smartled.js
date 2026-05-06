// 智能灯控制页面 - 阿里云IoT版
const { deviceService } = require('../../services/device-service');
const iotConfig = require('../../config/iot-config');

Page({
  data: {
    device: {
      name: '智能灯',
      image: '/images/icons/samrt_led_white.png',
      device_sn: ''  // 阿里云设备名称(DeviceName)
    },
    light: {
      isOn: false,
      brightness: 50,
      hue: 0,
      saturation: 100,
      temperature: 2700
    },
    scenes: [
      { name: '暖光', hue: 30, saturation: 80, brightness: 60 },
      { name: '冷光', hue: 200, saturation: 60, brightness: 80 },
      { name: '白光', hue: 0, saturation: 0, brightness: 100 },
      { name: '彩光', hue: 120, saturation: 100, brightness: 70 }
    ],
    currentColor: { r: 255, g: 255, b: 255 },
    connectionStatus: 'disconnected'  // disconnected, connected, error
  },

  statusTimer: null,

  onLoad() {
    const deviceSn = iotConfig.deviceNameSmartled || iotConfig.deviceName || wx.getStorageSync('deviceNameSmartled');
    if (deviceSn) {
      this.setData({ 'device.device_sn': deviceSn });
      this.setData({ connectionStatus: 'connected' });
      this.fetchDeviceStatus();
      this.startStatusPolling();
    } else {
      this.setData({ connectionStatus: 'error' });
      wx.showToast({ title: '请在 config/iot-config.js 配置 deviceNameSmartled', icon: 'none', duration: 3000 });
    }
    this.updateColorPreview();
  },

  onUnload() {
    if (this.statusTimer) clearInterval(this.statusTimer);
  },

  getDeviceId() {
    return this.data.device.device_sn;
  },

  toggleLight() {
    const newState = !this.data.light.isOn;
    this.setData({ 'light.isOn': newState });
    const deviceId = this.getDeviceId();
    if (!deviceId) return;
    deviceService.controlDevice(deviceId, { ledswitch: newState ? 1 : 0 })
      .then(() => wx.showToast({ title: '已' + (newState ? '开启' : '关闭'), icon: 'success' }))
      .catch(err => {
        this.setData({ 'light.isOn': !newState });
        wx.showToast({ title: err.message || '控制失败', icon: 'none' });
      });
  },

  changeBrightness(e) {
    const brightness = parseInt(e.detail.value, 10);
    this.setData({ 'light.brightness': brightness });
    this.updateColorPreview();
    this.sendLightCommand({ lightBrightness: brightness });
  },

  changeHue(e) {
    const hue = parseInt(e.detail.value, 10);
    this.setData({ 'light.hue': hue });
    this.updateColorPreview();
    this.sendLightCommand({ hue });
  },

  changeSaturation(e) {
    const saturation = parseInt(e.detail.value, 10);
    this.setData({ 'light.saturation': saturation });
    this.updateColorPreview();
    this.sendLightCommand({ saturation });
  },

  changeTemperature(e) {
    const temperature = parseInt(e.detail.value, 10);
    this.setData({ 'light.temperature': temperature });
    this.updateColorPreview();
    this.sendLightCommand({ temperature });
  },

  sendLightCommand(cmd) {
    const deviceId = this.getDeviceId();
    if (!deviceId) return;
    deviceService.controlDevice(deviceId, cmd).catch(err =>
      wx.showToast({ title: err.message || '控制失败', icon: 'none' })
    );
  },

  applyScene(e) {
    const scene = this.data.scenes[e.currentTarget.dataset.sceneIndex];
    this.setData({
      'light.hue': scene.hue,
      'light.saturation': scene.saturation,
      'light.brightness': scene.brightness
    });
    this.updateColorPreview();
    this.sendLightCommand({
      hue: scene.hue,
      saturation: scene.saturation,
      lightBrightness: scene.brightness
    });
    wx.showToast({ title: `已应用${scene.name}`, icon: 'success' });
  },

  updateColorPreview() {
    const { hue, saturation, brightness, temperature } = this.data.light;
    const rgb = saturation < 20
      ? this.temperatureToRgb(temperature, brightness / 100)
      : this.hsvToRgb(hue, saturation / 100, brightness / 100);
    this.setData({ currentColor: rgb });
  },

  hsvToRgb(h, s, v) {
    h = h / 360;
    const i = Math.floor(h * 6);
    const f = h * 6 - i;
    const p = v * (1 - s);
    const q = v * (1 - f * s);
    const t = v * (1 - (1 - f) * s);
    let r, g, b;
    switch (i % 6) {
      case 0: r = v; g = t; b = p; break;
      case 1: r = q; g = v; b = p; break;
      case 2: r = p; g = v; b = t; break;
      case 3: r = p; g = q; b = v; break;
      case 4: r = t; g = p; b = v; break;
      default: r = v; g = p; b = q;
    }
    return { r: Math.round(r * 255), g: Math.round(g * 255), b: Math.round(b * 255) };
  },

  temperatureToRgb(temperature, brightness) {
    let r, g, b;
    if (temperature <= 4000) {
      const t = (temperature - 2700) / 1300;
      r = 255; g = 255 * (0.8 + 0.2 * t); b = 255 * (0.6 + 0.4 * t);
    } else {
      const t = (temperature - 4000) / 2500;
      r = 255; g = 255 * (1.0 - 0.1 * t); b = 255 * (1.0 + 0.1 * t);
    }
    return {
      r: Math.round(r * brightness), g: Math.round(g * brightness), b: Math.round(b * brightness)
    };
  },

  fetchDeviceStatus() {
    const deviceId = this.getDeviceId();
    if (!deviceId) return;
    deviceService.getDeviceStatus(deviceId)
      .then(status => {
        const on =
          status.power === true ||
          status.power === 'true' ||
          status.power === 1 ||
          status.power === '1' ||
          status.ledswitch === 1 ||
          status.PowerSwitch === 1 ||
          status.isOn === true;
        const toNum = (v, def) => {
          const n = Number(v);
          return Number.isFinite(n) ? n : def;
        };
        this.setData({
          'light.isOn': !!on,
          'light.brightness': toNum(status.brightness ?? status.lightBrightness, 50),
          'light.hue': toNum(status.hue, 0),
          'light.saturation': toNum(status.saturation, 100),
          'light.temperature': toNum(status.temperature, 2700)
        });
        this.updateColorPreview();
      })
      .catch(() => {});
  },

  startStatusPolling() {
    if (this.statusTimer) clearInterval(this.statusTimer);
    this.statusTimer = setInterval(() => this.fetchDeviceStatus(), 5000);
  }
});
