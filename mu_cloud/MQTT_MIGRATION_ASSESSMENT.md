# WebSocket到MQTT迁移工作量评估

## 📋 项目现状分析

### 当前WebSocket使用情况统计

| 模块 | 文件路径 | WebSocket实现状态 | 代码行数(估) | 复杂度 |
|------|---------|------------------|-------------|--------|
| 智能LED灯 | `pages/smartled/smartled.js` | ✅ 已完整实现 | ~1200行 | ⭐⭐⭐⭐ |
| 智能浇花 | `pages/bloomIQ/bloomIQ.js` | ✅ 已完整实现 | ~730行 | ⭐⭐⭐⭐ |
| 智能窗帘 | `pages/curtain/curtain.js` | ✅ 已完整实现 | ~700行 | ⭐⭐⭐ |
| 设备设置 | `pages/device-settings/device-settings.js` | ✅ 已完整实现 | ~550行 | ⭐⭐⭐ |
| 智能插座 | `pages/socket/socket.js` | ⚠️ 仅模拟实现 | ~187行 | ⭐ |
| 红外控制器 | `pages/ir-controller/ir-controller.js` | ⚠️ 仅模拟实现 | ~191行 | ⭐ |

**合计：** 6个模块，4个完整实现，2个待实现

### 当前架构的WebSocket使用模式

#### 1. **连接管理模式**
```javascript
// 每个页面独立建立WebSocket连接
connectWebSocket: function() {
  const wsUrl = `ws://${ip}:${port}`;
  this.socketTask = wx.connectSocket({ url: wsUrl });
  
  this.socketTask.onOpen(() => { ... });
  this.socketTask.onMessage((res) => { ... });
  this.socketTask.onClose(() => { ... });
  this.socketTask.onError((err) => { ... });
}
```

**问题：**
- ❌ 每个设备页面创建独立连接
- ❌ 切换页面需要重新建立连接
- ❌ 资源浪费（微信小程序限制最多5个并发连接）
- ❌ 手动实现心跳机制
- ❌ 手动实现重连逻辑

#### 2. **消息格式**
```javascript
// 发送消息示例
{
  "ver": "1.0",
  "type": "control_request",
  "product": "bloomiq",
  "device_sn": "bloomiq_001",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": { ... }
}
```

#### 3. **核心功能模块**
每个设备页面都重复实现了以下功能：

| 功能模块 | 平均代码行数 | 重复次数 | 总代码量 |
|---------|-------------|---------|---------|
| WebSocket连接管理 | 60行 | 4次 | 240行 |
| 消息发送封装 | 40行 | 4次 | 160行 |
| 消息接收处理 | 50行 | 4次 | 200行 |
| 状态查询逻辑 | 30行 | 4次 | 120行 |
| 控制命令逻辑 | 40行 | 4次 | 160行 |
| 心跳重连机制 | 50行 | 4次 | 200行 |
| 错误处理 | 30行 | 4次 | 120行 |

**总计：** ~1,200行重复代码

---

## 🎯 迁移目标架构

### MQTT架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                        小程序层                              │
├──────────────┬──────────────┬──────────────┬────────────────┤
│  BloomIQ页面 │  SmartLED页面│  Curtain页面 │  其他设备页面   │
└──────────────┴──────────────┴──────────────┴────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   MQTT连接管理器 (单例)                       │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐             │
│  │ 连接管理   │  │ 消息路由   │  │ 重连管理   │             │
│  └────────────┘  └────────────┘  └────────────┘             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
              ┌──────────────────────────┐
              │     MQTT Broker          │
              │  (阿里云IoT / Mosquitto)  │
              └──────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
      ┌──────────────┐          ┌──────────────┐
      │  设备A       │          │  设备B       │
      │  (BloomIQ)   │          │  (SmartLED)  │
      └──────────────┘          └──────────────┘
```

### Topic设计

```
mucloud/{device_type}/{device_id}/control     # 控制命令
mucloud/{device_type}/{device_id}/status      # 状态上报
mucloud/{device_type}/{device_id}/response    # 响应消息
mucloud/{device_type}/+/status                # 订阅所有设备状态
mucloud/broadcast/control                     # 广播控制
```

**示例：**
```
mucloud/bloomiq/bloomiq_001/control           # 控制浇花设备001
mucloud/smartled/led_001/status               # 智能灯001状态上报
mucloud/curtain/+/control                     # 控制所有窗帘
```

---

## 📊 详细工作量评估

### Phase 1: 基础设施搭建 (2-3天)

| 任务 | 工作内容 | 预估工时 | 优先级 |
|------|---------|---------|--------|
| 1.1 选择MQTT库 | 调研并选择适合微信小程序的MQTT库（推荐：mqtt.js） | 0.5天 | P0 |
| 1.2 封装MQTT管理器 | 创建`utils/mqtt-manager.js`，实现单例模式 | 1天 | P0 |
| 1.3 连接管理 | 实现connect、disconnect、reconnect逻辑 | 0.5天 | P0 |
| 1.4 Topic规范 | 设计并文档化Topic命名规范 | 0.5天 | P0 |
| 1.5 消息路由器 | 实现基于Topic的消息分发机制 | 0.5天 | P0 |

**小计：** 3天

#### 核心文件清单：
```
utils/
├── mqtt-manager.js        # MQTT连接管理器（新建）
├── mqtt-topics.js         # Topic定义和工具函数（新建）
└── mqtt-message-router.js # 消息路由器（新建）
```

---

### Phase 2: 设备页面迁移 (5-7天)

#### 2.1 智能LED灯迁移 (1.5天)

| 子任务 | 工作内容 | 预估工时 |
|-------|---------|---------|
| 移除WebSocket代码 | 删除`connectWebSocket`等方法 | 0.5h |
| 集成MQTT管理器 | 引入mqtt-manager，初始化连接 | 1h |
| 修改状态查询 | 订阅`mucloud/smartled/{id}/status` | 1h |
| 修改控制命令 | 发布到`mucloud/smartled/{id}/control` | 1.5h |
| 修改消息处理 | 使用消息路由器处理响应 | 2h |
| 测试验证 | 完整功能测试 | 3h |

**主要修改文件：**
- `pages/smartled/smartled.js` (重构)
- `pages/smartled/DEVICE_CONTROL_PROTOCOL.md` (更新)

#### 2.2 智能浇花设备迁移 (1.5天)

| 子任务 | 工作内容 | 预估工时 |
|-------|---------|---------|
| 移除WebSocket代码 | 删除WebSocket相关代码 | 0.5h |
| 集成MQTT | 接入mqtt-manager | 1h |
| 修改传感器数据订阅 | 订阅`mucloud/bloomiq/{id}/status` | 1h |
| 修改水泵控制 | 发布到`mucloud/bloomiq/{id}/control` | 1h |
| 心跳机制调整 | 使用MQTT的Keep Alive | 0.5h |
| 测试验证 | 完整功能测试 | 3h |

**主要修改文件：**
- `pages/bloomIQ/bloomIQ.js` (重构)
- `pages/bloomIQ/DATA_TRANSMISSION_PROTOCOL.md` (更新)

#### 2.3 智能窗帘迁移 (1天)

| 子任务 | 工作内容 | 预估工时 |
|-------|---------|---------|
| 移除WebSocket代码 | 删除WebSocket相关代码 | 0.5h |
| 集成MQTT | 接入mqtt-manager | 0.5h |
| 修改状态查询 | 订阅curtain主题 | 1h |
| 修改控制命令 | 窗帘开关、位置控制 | 1h |
| 测试验证 | 完整功能测试 | 2h |

**主要修改文件：**
- `pages/curtain/curtain.js` (重构)

#### 2.4 设备设置页迁移 (1天)

| 子任务 | 工作内容 | 预估工时 |
|-------|---------|---------|
| 移除WebSocket代码 | 删除WebSocket相关代码 | 0.5h |
| 集成MQTT | 接入mqtt-manager | 0.5h |
| 修改设备配置同步 | 使用MQTT发送配置 | 1.5h |
| 测试多设备配置 | 测试不同设备类型 | 2h |

**主要修改文件：**
- `pages/device-settings/device-settings.js` (重构)

#### 2.5 智能插座实现 (1天)

| 子任务 | 工作内容 | 预估工时 |
|-------|---------|---------|
| 移除模拟代码 | 删除setTimeout模拟 | 0.5h |
| 实现MQTT通信 | 完整的MQTT控制逻辑 | 2h |
| 功率监控实现 | 实时功率数据订阅 | 1.5h |
| 定时功能实现 | 定时开关MQTT实现 | 1h |
| 测试验证 | 完整功能测试 | 2h |

**主要修改文件：**
- `pages/socket/socket.js` (实现)

#### 2.6 红外控制器实现 (1天)

| 子任务 | 工作内容 | 预估工时 |
|-------|---------|---------|
| 移除模拟代码 | 删除模拟实现 | 0.5h |
| 实现MQTT通信 | IR命令发送通道 | 1.5h |
| 学习模式实现 | 红外学习功能 | 1.5h |
| 设备类型管理 | TV/AC/Fan等控制 | 1h |
| 测试验证 | 完整功能测试 | 2h |

**主要修改文件：**
- `pages/ir-controller/ir-controller.js` (实现)

**Phase 2 小计：** 7天

---

### Phase 3: 公共组件升级 (1-2天)

| 任务 | 工作内容 | 预估工时 | 优先级 |
|------|---------|---------|--------|
| 3.1 Home页面集成 | 多设备状态同时订阅 | 0.5天 | P1 |
| 3.2 mDNS服务适配 | mDNS发现后通过MQTT连接 | 0.5天 | P1 |
| 3.3 设备服务重构 | `services/device-service.js`改用MQTT | 0.5天 | P1 |
| 3.4 全局连接管理 | app.js中初始化MQTT管理器 | 0.5天 | P0 |

**主要修改文件：**
- `pages/home/home.js` (修改)
- `utils/mdns-service.js` (修改)
- `services/device-service.js` (重构)
- `app.js` (修改)

**Phase 3 小计：** 2天

---

### Phase 4: 高级功能实现 (2-3天)

| 任务 | 工作内容 | 预估工时 | 优先级 |
|------|---------|---------|--------|
| 4.1 离线消息队列 | 实现QoS 1保证消息送达 | 0.5天 | P1 |
| 4.2 遗嘱消息 | 设备异常离线通知 | 0.5天 | P1 |
| 4.3 群组控制 | 一键控制多个设备 | 0.5天 | P2 |
| 4.4 场景联动 | 基于MQTT的场景自动化 | 1天 | P2 |
| 4.5 消息持久化 | 保留消息(Retained)实现 | 0.5天 | P2 |

**新增文件：**
```
utils/
├── mqtt-offline-queue.js    # 离线消息队列（新建）
├── mqtt-group-control.js    # 群组控制（新建）
└── mqtt-scene-manager.js    # 场景管理（新建）

pages/
└── scene/                   # 场景管理页面（新建）
    ├── scene.js
    ├── scene.wxml
    └── scene.wxss
```

**Phase 4 小计：** 3天

---

### Phase 5: 测试与优化 (2-3天)

| 任务 | 工作内容 | 预估工时 | 优先级 |
|------|---------|---------|--------|
| 5.1 单元测试 | 为mqtt-manager编写测试 | 0.5天 | P1 |
| 5.2 集成测试 | 测试所有设备页面 | 1天 | P0 |
| 5.3 弱网测试 | 模拟网络抖动、断网重连 | 0.5天 | P0 |
| 5.4 性能优化 | 消息压缩、连接池优化 | 0.5天 | P1 |
| 5.5 文档更新 | 更新所有协议文档 | 0.5天 | P1 |

**需要更新的文档：**
- `pages/bloomIQ/DATA_TRANSMISSION_PROTOCOL.md`
- `pages/bloomIQ/DEVICE_CONTROL_PROTOCOL.md`
- `pages/smartled/DEVICE_CONTROL_PROTOCOL.md`
- `README.md` (新增MQTT架构说明)

**Phase 5 小计：** 3天

---

## 📈 工作量总结

| 阶段 | 预估工时（人天） | 风险系数 | 实际预留（人天） |
|------|----------------|---------|----------------|
| Phase 1: 基础设施搭建 | 3天 | 1.2x | 3.5天 |
| Phase 2: 设备页面迁移 | 7天 | 1.3x | 9天 |
| Phase 3: 公共组件升级 | 2天 | 1.2x | 2.5天 |
| Phase 4: 高级功能实现 | 3天 | 1.5x | 4.5天 |
| Phase 5: 测试与优化 | 3天 | 1.3x | 4天 |
| **总计** | **18天** | - | **23.5天（约1个月）** |

### 人力配置建议

**方案A：单人全职**
- 1个全栈开发工程师
- 预计时间：**1个月**
- 风险：较高，没有review和并行工作

**方案B：双人协作（推荐）**
- 1个后端工程师（负责MQTT基础设施）
- 1个前端工程师（负责页面迁移）
- 预计时间：**2-3周**
- 风险：中等，有代码review

**方案C：快速迁移**
- 2个全栈工程师并行工作
- 预计时间：**10-12天**
- 风险：需要良好的协作和规范

---

## 🔍 代码修改统计

### 需要修改的文件

| 类型 | 文件数量 | 总代码行数(估) | 修改程度 |
|------|---------|--------------|---------|
| 新建文件 | 6个 | ~1,500行 | 100% |
| 重度修改 | 6个 | ~3,500行 | 60-80% |
| 中度修改 | 4个 | ~1,000行 | 30-50% |
| 轻度修改 | 3个 | ~500行 | 10-20% |

### 详细文件清单

#### ✅ 新建文件 (6个)

```
utils/mqtt-manager.js              # MQTT连接管理器 (~300行)
utils/mqtt-topics.js               # Topic定义 (~100行)
utils/mqtt-message-router.js       # 消息路由 (~200行)
utils/mqtt-offline-queue.js        # 离线队列 (~150行)
utils/mqtt-group-control.js        # 群组控制 (~200行)
MQTT_MIGRATION_GUIDE.md            # 迁移指南文档 (~500行)
```

#### 🔧 重度修改 (6个) - 60-80%代码变更

```
pages/smartled/smartled.js         # ~700行需要修改
pages/bloomIQ/bloomIQ.js           # ~400行需要修改
pages/curtain/curtain.js           # ~350行需要修改
pages/device-settings/device-settings.js  # ~300行需要修改
pages/socket/socket.js             # ~150行需要修改
pages/ir-controller/ir-controller.js  # ~150行需要修改
```

#### 🔨 中度修改 (4个) - 30-50%代码变更

```
pages/home/home.js                 # ~150行需要修改
utils/mdns-service.js              # ~100行需要修改
services/device-service.js         # ~80行需要修改
app.js                             # ~50行需要修改
```

#### ✏️ 轻度修改 (3个) - 10-20%代码变更

```
config/iot-config.js               # 添加MQTT配置
pages/setup/setup.js               # 配网后保存MQTT信息
utils/monitor.js                   # 添加MQTT监控指标
```

#### 📄 文档更新 (8个)

```
pages/bloomIQ/DATA_TRANSMISSION_PROTOCOL.md
pages/bloomIQ/DEVICE_CONTROL_PROTOCOL.md
pages/bloomIQ/DEVICE_RESPONSE_FORMAT.md
pages/smartled/DEVICE_CONTROL_PROTOCOL.md
pages/smartled/DEVICE_RESPONSE_FORMAT.md
pages/setup/配网流程文档.md
README.md
mDNS_WeChat_Article.md
```

**代码修改总计：**
- 新增代码：~1,450行
- 修改代码：~2,280行
- 删除代码：~1,200行（重复WebSocket代码）
- **净增代码：~1,530行**

---

## ⚠️ 风险评估

### 高风险项 (🔴)

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| **微信小程序MQTT库兼容性** | 高 | 中 | 提前验证`mqtt.js`在小程序环境运行，准备降级方案 |
| **设备端MQTT协议支持** | 高 | 中 | 需要硬件团队同步升级设备固件 |
| **数据迁移和向后兼容** | 高 | 低 | 保留WebSocket作为fallback，渐进式迁移 |
| **并发连接限制** | 中 | 低 | 单例模式保证只有一个MQTT连接 |

### 中风险项 (🟡)

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| **消息格式不兼容** | 中 | 中 | 设计兼容层，支持新旧格式 |
| **局域网vs云端通信** | 中 | 中 | 设计混合模式，局域网优先 |
| **MQTT Broker选择** | 中 | 低 | 阿里云IoT原生支持MQTT，可直接使用 |
| **测试覆盖不足** | 中 | 中 | 编写详细测试用例，使用真实设备测试 |

### 低风险项 (🟢)

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| **开发进度延期** | 低 | 中 | 充足的时间buffer（30%） |
| **文档滞后** | 低 | 高 | 边开发边更新文档 |
| **团队学习曲线** | 低 | 中 | 提供MQTT培训和示例代码 |

---

## 💡 实施建议

### 迁移策略：渐进式迁移（推荐）

#### 阶段1：基础设施（Week 1）
```
✓ 搭建MQTT Manager
✓ 选择并验证MQTT库
✓ 设计Topic规范
✓ 编写示例代码
```

#### 阶段2：单个设备试点（Week 2）
```
✓ 选择SmartLED作为试点设备
✓ 完整迁移并测试
✓ 验证性能和稳定性
✓ 确认架构设计合理
```

#### 阶段3：批量迁移（Week 3）
```
✓ 迁移BloomIQ
✓ 迁移Curtain
✓ 迁移Device-Settings
✓ 实现Socket和IR-Controller
```

#### 阶段4：收尾优化（Week 4）
```
✓ 高级功能实现
✓ 全面测试
✓ 性能优化
✓ 文档完善
```

### 技术方案推荐

#### 1. MQTT库选择

**推荐：mqtt.js**
```bash
npm install mqtt --save
```

**理由：**
- ✅ 支持微信小程序环境
- ✅ 功能完善，API友好
- ✅ 社区活跃，文档齐全
- ✅ 支持QoS、Will Message等高级特性

#### 2. MQTT Broker选择

**方案A：阿里云IoT平台（推荐）**
- ✅ 已在使用，无需额外部署
- ✅ 原生支持MQTT协议
- ✅ 稳定可靠，有监控和日志
- ❌ 成本相对较高

**方案B：自建Mosquitto**
- ✅ 完全免费开源
- ✅ 配置灵活
- ❌ 需要运维维护
- ❌ 需要处理安全性问题

**方案C：混合模式（最灵活）**
- 局域网：直连设备（WebSocket或MQTT）
- 远程控制：阿里云IoT MQTT
- 自动切换，优先局域网

#### 3. Topic设计规范

```javascript
// utils/mqtt-topics.js
const TOPICS = {
  // 控制主题
  control: (deviceType, deviceId) => 
    `mucloud/${deviceType}/${deviceId}/control`,
  
  // 状态主题
  status: (deviceType, deviceId) => 
    `mucloud/${deviceType}/${deviceId}/status`,
  
  // 响应主题
  response: (deviceType, deviceId) => 
    `mucloud/${deviceType}/${deviceId}/response`,
  
  // 订阅所有设备状态
  statusAll: (deviceType) => 
    `mucloud/${deviceType}/+/status`,
  
  // 广播控制
  broadcast: () => 
    `mucloud/broadcast/control`
};
```

---

## 📝 关键代码示例

### 1. MQTT管理器骨架

```javascript
// utils/mqtt-manager.js
const mqtt = require('mqtt');

class MQTTManager {
  static instance = null;
  
  static getInstance() {
    if (!MQTTManager.instance) {
      MQTTManager.instance = new MQTTManager();
    }
    return MQTTManager.instance;
  }
  
  constructor() {
    this.client = null;
    this.connected = false;
    this.subscribers = new Map(); // topic -> [callbacks]
  }
  
  connect(options) {
    const { 
      brokerUrl, 
      clientId, 
      username, 
      password 
    } = options;
    
    this.client = mqtt.connect(brokerUrl, {
      clientId: clientId || `miniprogram_${Date.now()}`,
      username,
      password,
      clean: false,        // 持久会话
      keepalive: 60,       // 心跳60秒
      reconnectPeriod: 1000,
      connectTimeout: 30 * 1000
    });
    
    this.client.on('connect', () => {
      console.log('MQTT已连接');
      this.connected = true;
      this.resubscribeAll();
    });
    
    this.client.on('message', (topic, payload) => {
      this.handleMessage(topic, payload);
    });
    
    this.client.on('error', (err) => {
      console.error('MQTT错误:', err);
    });
  }
  
  subscribe(topic, callback) {
    if (!this.subscribers.has(topic)) {
      this.subscribers.set(topic, []);
      this.client.subscribe(topic, { qos: 1 });
    }
    this.subscribers.get(topic).push(callback);
  }
  
  publish(topic, message, options = {}) {
    const payload = JSON.stringify(message);
    this.client.publish(topic, payload, {
      qos: options.qos || 1,
      retain: options.retain || false
    });
  }
  
  handleMessage(topic, payload) {
    const callbacks = this.subscribers.get(topic) || [];
    const message = JSON.parse(payload.toString());
    callbacks.forEach(cb => cb(message));
  }
}

module.exports = MQTTManager;
```

### 2. 设备页面迁移示例

```javascript
// pages/smartled/smartled.js - 迁移后
const MQTTManager = require('../../utils/mqtt-manager');
const { TOPICS } = require('../../utils/mqtt-topics');

Page({
  data: { /* ... */ },
  
  onLoad(options) {
    const deviceInfo = JSON.parse(decodeURIComponent(options.deviceInfo));
    this.mqttManager = MQTTManager.getInstance();
    
    // 订阅设备状态
    const statusTopic = TOPICS.status('smartled', deviceInfo.device_sn);
    this.mqttManager.subscribe(statusTopic, (message) => {
      this.handleDeviceStatus(message);
    });
    
    // 订阅响应
    const responseTopic = TOPICS.response('smartled', deviceInfo.device_sn);
    this.mqttManager.subscribe(responseTopic, (message) => {
      this.handleDeviceResponse(message);
    });
  },
  
  // 控制LED
  toggleLight() {
    const controlTopic = TOPICS.control('smartled', this.data.device.device_sn);
    this.mqttManager.publish(controlTopic, {
      ver: "1.0",
      type: "control_request",
      product: "smartled",
      device_sn: this.data.device.device_sn,
      timestamp: new Date().toISOString(),
      data: {
        command: "toggle",
        params: { isOn: !this.data.light.isOn }
      }
    }, { qos: 1 });
  }
});
```

### 3. 消息格式兼容层

```javascript
// utils/mqtt-message-adapter.js
class MessageAdapter {
  // WebSocket格式 -> MQTT格式
  static wsToMqtt(wsMessage) {
    return {
      ...wsMessage,
      protocol: 'mqtt',
      qos: 1
    };
  }
  
  // MQTT格式 -> WebSocket格式
  static mqttToWs(mqttMessage) {
    return {
      ...mqttMessage,
      protocol: 'websocket'
    };
  }
}
```

---

## 💰 成本效益分析

### 一次性成本

| 项目 | 成本 |
|------|------|
| 开发人力成本（1个月） | 根据实际薪资 |
| MQTT库License | 免费(MIT) |
| 阿里云IoT费用 | 已有，无额外成本 |
| 测试设备采购 | 已有，无额外成本 |

### 长期收益

| 收益项 | 估算 |
|-------|------|
| **代码维护成本降低** | -50% (消除重复代码) |
| **新设备接入时间** | -70% (复用MQTT基础设施) |
| **设备并发支持** | 从5个提升到理论无限 |
| **离线消息可靠性** | 从0%提升到99.9% |
| **开发人员学习成本** | -60% (统一架构) |

### ROI计算

假设：
- 迁移成本：1个月开发时间
- 每次新设备接入节省：3天 → 0.9天（节省2.1天）
- 年新设备数量：4个
- 年节省时间：8.4天

**ROI ≈ (8.4天 / 20天) × 100% = 42%**

如果考虑代码维护成本降低和系统稳定性提升：
**实际ROI > 100%**（通常在第一年内收回成本）

---

## ✅ 下一步行动

### 立即行动项

1. **技术验证（本周）**
   - [ ] 在微信小程序中验证mqtt.js可用性
   - [ ] 搭建本地Mosquitto测试环境
   - [ ] 编写Hello World示例

2. **方案评审（下周）**
   - [ ] 召开技术评审会议
   - [ ] 确认迁移策略和时间线
   - [ ] 分配任务和责任人

3. **启动开发（2周后）**
   - [ ] 创建feature分支
   - [ ] 搭建MQTT基础设施
   - [ ] 开始试点设备迁移

### 决策要点

需要Product Owner/Tech Lead确认：

1. **是否启动迁移？**
   - ✅ 推荐启动（长期收益明显）
   - ❌ 暂不启动（如果人力紧张）

2. **迁移策略选择**
   - ✅ 渐进式迁移（推荐）
   - ❌ 大爆炸迁移（风险高）
   - ⚠️  混合架构（临时方案）

3. **MQTT Broker选择**
   - ✅ 阿里云IoT（推荐）
   - ⚠️  自建Mosquitto
   - ✅ 混合模式（最灵活）

---

## 📚 参考资源

### MQTT学习资源
- [MQTT官方文档](https://mqtt.org/)
- [mqtt.js GitHub](https://github.com/mqttjs/MQTT.js)
- [阿里云IoT MQTT接入](https://help.aliyun.com/document_detail/30540.html)

### 小程序开发文档
- [微信小程序网络API](https://developers.weixin.qq.com/miniprogram/dev/api/network/request/wx.request.html)
- [微信小程序WebSocket](https://developers.weixin.qq.com/miniprogram/dev/api/network/websocket/wx.connectSocket.html)

### 项目内部文档
- `mDNS_WeChat_Article.md` - mDNS服务详解
- `pages/bloomIQ/DATA_TRANSMISSION_PROTOCOL.md` - 现有数据传输协议
- `WEBSOCKET_DEVICE_SELECTION_FIX.md` - WebSocket修复记录

---

## 📞 联系方式

如有疑问或需要技术支持，请联系：
- 项目负责人：[待填写]
- 技术架构师：[待填写]
- 硬件团队：[待填写]

---

**文档版本：** v1.0
**创建日期：** 2025-10-07
**最后更新：** 2025-10-07
**作者：** AI Assistant

