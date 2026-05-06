# 阿里云IoT设备控制 - 微信小程序开源版

> 版本：v1.0.0

基于阿里云物联网平台的小程序模板，支持智能灯和智能插座的远程控制。可连接个人阿里云账号下的 IoT 设备，便于二次开发和扩展。

## 功能

- **智能灯**：开关、亮度、色相、饱和度、色温、预设场景
- **智能插座**：开关控制、电气参数展示、定时设置

## 快速开始

1. 克隆项目，使用微信开发者工具打开
2. 在 `project.config.json` 中将 `appid` 改为你自己的小程序 AppID（仓库内默认为占位符 `wx0000000000000000`）
3. 编辑 `config/iot-config.js`（模板与仓库内默认占位符一致，见 `config/iot-config.js.example`），填入真实 AccessKey、ProductKey、DeviceName；**勿将含真实密钥或真实 AppID 的提交推送到公开仓库**
4. 编译运行

## 前提条件

- 阿里云 IoT 平台账号
- 已创建产品并添加设备
- 获取 AccessKey、ProductKey、DeviceName

## 配置步骤

1. 编辑 `config/iot-config.js`：

```javascript
const config = {
  productKey: '您的产品Key',
  accessKeyId: '您的AccessKey ID',
  accessKeySecret: '您的AccessKey Secret',
  endpoint: 'https://iot.cn-shanghai.aliyuncs.com',
  deviceName: '默认设备名称',
  deviceNameSmartled: '智能灯设备名称',   // 可选
  deviceNameSocket: '智能插座设备名称',   // 可选
  smartledUseInvokeThingService: false, // 默认 false：用 SetDeviceProperty 下发属性（避免 service not found）
  smartledThingServiceIdentifier: 'set',
  socketThingServiceIdentifier: 'led_ctrl_data',
  iotInstanceId: undefined // 企业实例必填，见阿里云控制台实例概览
}
```

2. 确保阿里云 IoT 产品的物模型(TSL)与以下属性/服务匹配：
   - **智能灯（标准 Alink）**：属性 `power`、`brightness`、`hue`、`saturation`、`temperature`；服务 **`set`**（thing.service.property.set）。示例见 [docs/tsl/智能灯泡物模型示例.json](docs/tsl/智能灯泡物模型示例.json)
   - **智能插座**：plugSwitch 或 PowerSwitch（服务 Identifier 见 `socketThingServiceIdentifier`）

若产品使用不同标识符，可使用 `deviceService.invokeService(deviceId, args, '您的Identifier')`，详见 [扩展开发指南](docs/扩展开发指南.md)。

## 目录结构

```
├── pages/
│   ├── index/       # 首页入口
│   ├── smartled/    # 智能灯控制
│   └── socket/      # 智能插座控制
├── components/
│   └── header/      # 通用头部
├── services/
│   └── device-service.js   # 设备服务
├── utils/
│   ├── aliyun-connector.js # 阿里云连接器
│   └── aliIot-sdk.js      # 阿里云 IoT SDK
├── config/
│   └── iot-config.js      # 配置文件
└── docs/
    ├── 架构说明.md        # 项目架构
    ├── 扩展开发指南.md    # 新增设备指南
    └── 项目审计与改进.md  # 审计报告
```

## 开发文档

- [阿里云IoT连接配置指南](docs/阿里云IoT连接配置指南.md) - 个人测试时的阿里云平台配置步骤
- [架构说明](docs/架构说明.md) - 项目架构、数据流、目录职责
- [多设备支持架构说明](docs/多设备支持架构说明.md) - 支持控制多个设备的架构改造方案
- [扩展开发指南](docs/扩展开发指南.md) - 新增设备类型、API 说明

## 常见问题

**Q: process is not defined**  
A: 微信小程序无 `process.env`，配置请使用 `config/iot-config.js` 或 `wx.setStorageSync`。

**Q: 物模型 Identifier 与默认不同**  
A: 使用 `deviceService.invokeService(deviceId, args, '您的服务Identifier')`。

## License

MIT - 详见 [LICENSE](LICENSE)
