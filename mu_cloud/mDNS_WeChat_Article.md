# 微信小程序如何发现设备？mDNS服务详解

## 前言

在智能家居和物联网应用中，小程序经常需要发现和连接局域网内的设备。传统的做法是让用户手动输入IP地址，但这对普通用户来说太复杂了。今天我们来聊聊微信小程序中的mDNS服务，它能让设备"自动现身"！

## 什么是mDNS？

**mDNS（Multicast DNS）**是一种零配置网络服务发现协议。简单来说，就像在局域网里大声喊"我是智能灯泡，我在192.168.1.100"，其他设备都能听到并知道你在哪里。

### mDNS的优势
- ✅ **零配置**：无需手动设置IP地址
- ✅ **自动发现**：设备上线后自动被发现
- ✅ **动态更新**：IP变化后自动更新
- ✅ **用户友好**：小白用户也能轻松使用

## 微信小程序mDNS API详解

### 1. 启动本地服务发现

```javascript
wx.startLocalServiceDiscovery({
  serviceType: '_mucloud._tcp.',  // 服务类型，必须以下划线开头和结尾
  success: function(res) {
    console.log('开始搜索服务', res);
  },
  fail: function(err) {
    console.log('搜索失败', err);
  }
});
```

**参数详解：**
- `serviceType`：要搜索的服务类型，格式为`_服务名._协议.`
  - `_mucloud._tcp.`：搜索mucloud的TCP服务
  - `_http._tcp.`：搜索HTTP服务
  - `_ssh._tcp.`：搜索SSH服务

### 2. 监听服务发现事件

```javascript
// 监听发现新服务
wx.onLocalServiceFound(function(res) {
  console.log('发现新服务:', res);
  /*
  res结构：
  {
    serviceName: '智能灯泡_001',    // 服务名称
    serviceType: '_mucloud._tcp.',  // 服务类型
    ip: '192.168.1.100',           // 设备IP地址
    port: 8080,                    // 服务端口
    attributes: {                  // 额外属性
      device_id: 'light_001',
      product_type: 'smart_led'
    }
  }
  */
});

// 监听服务丢失
wx.onLocalServiceLost(function(res) {
  console.log('服务丢失:', res);
});
```

**事件参数详解：**
- `serviceName`：设备的友好名称，如"智能灯泡_001"
- `serviceType`：服务的类型标识
- `ip`：设备的IP地址
- `port`：服务监听的端口号
- `attributes`：设备的额外信息，如设备ID、产品类型等

### 3. 停止服务发现

```javascript
wx.stopLocalServiceDiscovery({
  success: function(res) {
    console.log('停止搜索成功', res);
  },
  fail: function(err) {
    console.log('停止搜索失败', err);
  }
});
```

## 实际应用示例

### 完整的设备发现流程

```javascript
// 智能设备发现管理器
class DeviceDiscoveryManager {
  constructor() {
    this.discoveredDevices = [];  // 已发现的设备列表
    this.searching = false;       // 是否正在搜索
  }

  /**
   * 开始搜索智能设备
   * @param {string} serviceType - 服务类型
   * @param {number} timeout - 超时时间（毫秒）
   */
  startSearch(serviceType = '_mucloud._tcp.', timeout = 10000) {
    if (this.searching) {
      console.log('正在搜索中，请稍候...');
      return;
    }

    this.searching = true;
    this.discoveredDevices = [];

    // 设置超时
    const timeoutId = setTimeout(() => {
      this.stopSearch();
      console.log('搜索超时，已停止');
    }, timeout);

    // 启动服务发现
    wx.startLocalServiceDiscovery({
      serviceType: serviceType,
      success: (res) => {
        console.log('开始搜索服务:', serviceType);
      },
      fail: (err) => {
        console.error('启动搜索失败:', err);
        this.searching = false;
        clearTimeout(timeoutId);
      }
    });

    // 监听发现事件
    wx.onLocalServiceFound((res) => {
      console.log('发现设备:', res);
      this.handleDeviceFound(res);
    });

    // 监听丢失事件
    wx.onLocalServiceLost((res) => {
      console.log('设备离线:', res);
      this.handleDeviceLost(res);
    });
  }

  /**
   * 处理发现的设备
   * @param {Object} deviceInfo - 设备信息
   */
  handleDeviceFound(deviceInfo) {
    // 检查是否已存在
    const existingIndex = this.discoveredDevices.findIndex(
      device => device.ip === deviceInfo.ip && device.port === deviceInfo.port
    );

    if (existingIndex >= 0) {
      // 更新现有设备信息
      this.discoveredDevices[existingIndex] = {
        ...this.discoveredDevices[existingIndex],
        ...deviceInfo,
        lastSeen: new Date().toISOString()
      };
    } else {
      // 添加新设备
      this.discoveredDevices.push({
        ...deviceInfo,
        lastSeen: new Date().toISOString(),
        status: 'online'
      });
    }

    console.log('当前已发现设备:', this.discoveredDevices);
    this.notifyDeviceUpdate();
  }

  /**
   * 处理设备丢失
   * @param {Object} deviceInfo - 设备信息
   */
  handleDeviceLost(deviceInfo) {
    const index = this.discoveredDevices.findIndex(
      device => device.ip === deviceInfo.ip && device.port === deviceInfo.port
    );

    if (index >= 0) {
      this.discoveredDevices[index].status = 'offline';
      this.discoveredDevices[index].lastSeen = new Date().toISOString();
      console.log('设备离线:', deviceInfo.serviceName);
      this.notifyDeviceUpdate();
    }
  }

  /**
   * 停止搜索
   */
  stopSearch() {
    if (!this.searching) return;

    wx.stopLocalServiceDiscovery({
      success: (res) => {
        console.log('停止搜索成功');
        this.searching = false;
      },
      fail: (err) => {
        console.error('停止搜索失败:', err);
      }
    });
  }

  /**
   * 获取发现的设备列表
   * @returns {Array} 设备列表
   */
  getDiscoveredDevices() {
    return this.discoveredDevices.filter(device => device.status === 'online');
  }

  /**
   * 通知设备列表更新
   */
  notifyDeviceUpdate() {
    // 这里可以触发页面更新或发送事件
    console.log('设备列表已更新，当前在线设备数量:', this.getDiscoveredDevices().length);
  }
}
```

### 在页面中使用

```javascript
// pages/device-discovery/device-discovery.js
Page({
  data: {
    deviceList: [],           // 设备列表
    searching: false,         // 是否正在搜索
    searchProgress: '准备搜索' // 搜索进度提示
  },

  onLoad() {
    // 初始化设备发现管理器
    this.discoveryManager = new DeviceDiscoveryManager();
  },

  /**
   * 开始搜索设备
   */
  startSearch() {
    this.setData({
      searching: true,
      searchProgress: '正在搜索设备...',
      deviceList: []
    });

    // 开始搜索，10秒超时
    this.discoveryManager.startSearch('_mucloud._tcp.', 10000);

    // 监听设备更新
    this.checkDevicesInterval = setInterval(() => {
      const devices = this.discoveryManager.getDiscoveredDevices();
      this.setData({
        deviceList: devices,
        searchProgress: `已发现 ${devices.length} 个设备`
      });
    }, 1000);
  },

  /**
   * 停止搜索
   */
  stopSearch() {
    this.discoveryManager.stopSearch();
    this.setData({
      searching: false,
      searchProgress: '搜索已停止'
    });

    if (this.checkDevicesInterval) {
      clearInterval(this.checkDevicesInterval);
    }
  },

  /**
   * 连接设备
   * @param {Event} e - 点击事件
   */
  connectDevice(e) {
    const { device } = e.currentTarget.dataset;
    console.log('连接设备:', device);

    // 跳转到设备控制页面
    wx.navigateTo({
      url: `/pages/device-control/device-control?deviceInfo=${encodeURIComponent(JSON.stringify(device))}`,
      success: () => {
        console.log('跳转到设备控制页面成功');
      },
      fail: (err) => {
        wx.showToast({
          title: '跳转失败',
          icon: 'none'
        });
      }
    });
  },

  onUnload() {
    // 页面卸载时停止搜索
    this.stopSearch();
  }
});
```

## 常见问题与解决方案

### 1. 搜索不到设备

**可能原因：**
- 设备没有正确注册mDNS服务
- 网络环境不支持多播
- 防火墙阻止了多播包

**解决方案：**
```javascript
// 增加重试机制
function searchWithRetry(serviceType, maxRetries = 3) {
  let retryCount = 0;
  
  function attemptSearch() {
    wx.startLocalServiceDiscovery({
      serviceType: serviceType,
      success: () => {
        console.log('搜索成功');
      },
      fail: (err) => {
        retryCount++;
        if (retryCount < maxRetries) {
          console.log(`搜索失败，${2}秒后重试 (${retryCount}/${maxRetries})`);
          setTimeout(attemptSearch, 2000);
        } else {
          console.error('搜索最终失败:', err);
        }
      }
    });
  }
  
  attemptSearch();
}
```

### 2. 设备频繁上下线

**解决方案：**
```javascript
// 添加设备状态缓存和去重
class DeviceCache {
  constructor() {
    this.devices = new Map();  // 使用Map存储设备
    this.onlineThreshold = 30000; // 30秒内没收到消息认为离线
  }

  updateDevice(deviceInfo) {
    const key = `${deviceInfo.ip}:${deviceInfo.port}`;
    const now = Date.now();
    
    this.devices.set(key, {
      ...deviceInfo,
      lastSeen: now,
      status: 'online'
    });
  }

  markOffline(deviceInfo) {
    const key = `${deviceInfo.ip}:${deviceInfo.port}`;
    const device = this.devices.get(key);
    
    if (device) {
      device.status = 'offline';
      device.lastSeen = Date.now();
    }
  }

  getOnlineDevices() {
    const now = Date.now();
    return Array.from(this.devices.values()).filter(device => 
      device.status === 'online' && 
      (now - device.lastSeen) < this.onlineThreshold
    );
  }
}
```

### 3. 性能优化

```javascript
// 限制搜索时间，避免长时间占用资源
function optimizedSearch(serviceType, duration = 8000) {
  const startTime = Date.now();
  
  wx.startLocalServiceDiscovery({
    serviceType: serviceType,
    success: () => {
      console.log('开始搜索');
      
      // 设置定时器自动停止
      setTimeout(() => {
        wx.stopLocalServiceDiscovery({
          success: () => {
            console.log('搜索完成');
          }
        });
      }, duration);
    }
  });
}
```

## 最佳实践建议

### 1. 用户体验优化

```javascript
// 添加搜索进度提示
function showSearchProgress(step, message) {
  wx.showLoading({
    title: message,
    mask: true
  });
  
  // 根据步骤显示不同提示
  const messages = {
    'start': '正在启动设备搜索...',
    'searching': '正在搜索局域网设备...',
    'found': '发现设备，正在获取信息...',
    'complete': '搜索完成'
  };
  
  return messages[step] || '正在处理...';
}
```

### 2. 错误处理

```javascript
// 完善的错误处理
function handleSearchError(error) {
  console.error('搜索错误:', error);
  
  let errorMessage = '设备搜索失败';
  
  switch(error.errMsg) {
    case 'startLocalServiceDiscovery:fail network error':
      errorMessage = '网络连接异常，请检查网络';
      break;
    case 'startLocalServiceDiscovery:fail permission denied':
      errorMessage = '权限不足，请授权网络访问';
      break;
    default:
      errorMessage = `搜索失败: ${error.errMsg}`;
  }
  
  wx.showModal({
    title: '搜索失败',
    content: errorMessage,
    showCancel: false,
    confirmText: '知道了'
  });
}
```

### 3. 内存管理

```javascript
// 页面卸载时清理资源
Page({
  onUnload() {
    // 停止服务发现
    wx.stopLocalServiceDiscovery();
    
    // 清除事件监听
    wx.offLocalServiceFound();
    wx.offLocalServiceLost();
    
    // 清除定时器
    if (this.searchTimer) {
      clearTimeout(this.searchTimer);
    }
  }
});
```

## 总结

mDNS服务发现是微信小程序连接局域网设备的重要技术。通过合理使用相关API，我们可以实现：

- 🎯 **自动设备发现**：无需手动配置IP地址
- 🔄 **动态设备管理**：实时监控设备上下线状态  
- 👥 **用户友好体验**：小白用户也能轻松使用
- 🚀 **高性能实现**：合理的内存和网络资源管理

掌握这些技术后，你就能开发出更加智能和易用的物联网小程序了！

---

**作者简介：** 专注于微信小程序和物联网开发，有丰富的智能家居项目经验。

**关注我们：** 获取更多小程序开发技巧和物联网技术分享！
