# 阿里云物联网平台连接微信小程序配置指南

本文档说明个人测试时，在阿里云物联网平台需完成的配置，以及如何连接本小程序。

## 一、阿里云账号准备

- 注册 [阿里云账号](https://www.aliyun.com/)
- 完成实名认证
- 开通物联网平台服务（有免费额度，适合个人测试）

## 二、创建产品（Product）

1. 登录 [物联网平台控制台](https://iot.console.aliyun.com/)
2. 进入 **设备管理 > 产品**，点击 **创建产品**
3. 配置参数：
   - **产品名称**：自定义（如「智能灯」「智能插座」）
   - **所属品类**：选择自定义品类
   - **节点类型**：直连设备
   - **连网方式**：Wi-Fi / 蜂窝等
   - **数据格式**：ICA 标准数据格式（Alink JSON）
   - **认证方式**：设备密钥
4. 创建成功后获得 **ProductKey**，请妥善保存

## 三、定义物模型（TSL）

在产品的 **物模型** 中定义属性，需与云端下发、查询使用的标识符一致。

### 智能灯（与当前开源版默认逻辑一致）

- **属性（读写）**：`power`（bool，云端下发用 **0/1**）、`brightness`、`hue`、`saturation`、`temperature`（色温 K）
- **状态查询**：`QueryDevicePropertyStatus`，返回上述属性；页面内仍用 `ledswitch` / `lightBrightness` 等**业务字段**，由 `device-service` 映射为 TSL 字段

**云端下发方式（当前默认）**：

- 使用 OpenAPI **`SetDeviceProperty`**，在 `Items` 中传 JSON，例如 `{"power":1}`、`{"brightness":50,"hue":180.0}`
- 若你的产品/实例支持通过 **`InvokeThingService`** 调用物模型服务 `set`，可在 `config/iot-config.js` 中设置 `smartledUseInvokeThingService: true`

物模型示例见：[tsl/智能灯泡物模型示例.json](tsl/智能灯泡物模型示例.json)

### 智能插座

- **属性**：常见为 `plugSwitch` 或 `PowerSwitch` 等（以控制台物模型为准）
- **下发**：当前通过 `controlDevice` 走 **`InvokeThingService`**，服务 Identifier 由 `socketThingServiceIdentifier` 配置（默认 `led_ctrl_data`，需与你的产品一致）

### 自定义服务或属性

若与默认不一致，请使用 `deviceService.invokeService(deviceId, args, '您的Identifier')`，或改 `iot-config` 中对应 Identifier / 映射逻辑。

## 四、创建设备（Device）

1. 进入 **设备管理 > 设备**
2. 选择对应产品，点击 **添加设备**
3. 输入设备名称（即 **DeviceName**）
4. 创建成功后，记录 **DeviceName** 和 **DeviceSecret**

## 五、获取 AccessKey

AccessKey 用于小程序调用阿里云 OpenAPI，建议使用 RAM 子账号以提高安全性。

### 方式一：主账号 AccessKey（仅测试用）

控制台右上角头像 → AccessKey 管理 → 创建 AccessKey

### 方式二：RAM 子账号（推荐）

1. 进入 [RAM 访问控制台](https://ram.console.aliyun.com/)
2. 身份管理 → 用户 → 创建用户
3. 为该用户创建 AccessKey
4. 授予权限策略：`AliyunIOTFullAccess`（或按需授予只读权限）

## 六、配置小程序

在项目 `config/iot-config.js` 中填入以下信息：

```javascript
const config = {
  productKey: '您的 ProductKey',
  accessKeyId: '您的 AccessKey ID',
  accessKeySecret: '您的 AccessKey Secret',
  endpoint: 'https://iot.cn-shanghai.aliyuncs.com',
  deviceName: '默认设备名称',
  deviceNameSmartled: '智能灯设备名称',
  deviceNameSocket: '智能插座设备名称',
  // 智能灯：默认 false，使用 SetDeviceProperty；true 则使用 InvokeThingService + smartledThingServiceIdentifier
  smartledUseInvokeThingService: false,
  smartledThingServiceIdentifier: 'set',
  socketThingServiceIdentifier: 'led_ctrl_data',
  // 企业版物联网实例 ID（控制台实例概览）；公共实例一般留空
  iotInstanceId: undefined
}
```

也可通过 `wx.setStorageSync('iotConfig', { ... })` 合并覆盖上述字段。

### endpoint 地域对照

| 地域       | endpoint                           |
|------------|-------------------------------------|
| 华东2(上海) | https://iot.cn-shanghai.aliyuncs.com |
| 华北2(北京) | https://iot.cn-beijing.aliyuncs.com  |

## 七、架构说明

- **设备**：直连阿里云 IoT，通过 MQTT 等协议上报属性
- **小程序**：通过阿里云 OpenAPI 查询与控制，例如：
  - **QueryDevicePropertyStatus**：读属性
  - **SetDeviceProperty**：智能灯默认写属性
  - **InvokeThingService**：插座或开启 `smartledUseInvokeThingService` 时的智能灯
- **安全**：小程序不直连设备，经由云端 API，不在端上存放设备证书

## 八、常见问题

**Q: 提示「请在 config/iot-config.js 配置」**  
A: 检查 productKey、accessKeyId、accessKeySecret 是否已正确填写，且与阿里云控制台一致。

**Q: 控制失败 `service not found`（InvokeThingService）**  
A: 许多标准物模型的「属性设置」服务无法在云端用 `InvokeThingService` 的 `set` 调用。保持 `smartledUseInvokeThingService: false`，使用 `SetDeviceProperty`。

**Q: `tsl parse: value of bool type must be int`**  
A: 物模型 bool 在 `SetDeviceProperty` 的 `Items` 中应使用 **0/1**，代码已对 `power` 做映射。

**Q: 多实例如何选择 endpoint**  
A: 在物联网平台控制台查看实例所在地域；企业实例还需配置 `iotInstanceId`。

**Q: 日志里看到 `items.power.value`，是不是没发控制？**  
A: 这是平台到设备侧的封装，`value` 即为下发的属性值（如 0 表示关）。
