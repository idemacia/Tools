# NotesDesk

macOS 桌面备忘录展示 + 群晖 Docker 待办服务 + 瘦客户端。

## 谁该用什么

| 你是… | 需要什么 | 不需要 |
|--------|----------|--------|
| **群晖 NAS 用户（大多数）** | [Releases 下载 tar](notes-desk-server/release/README.md) + [安装与配置指南](notes-desk-server/docs/安装与配置指南.md) | 不必看源码、不必 `docker build` |
| **Mac 读备忘录** | [notes-desk-panel](notes-desk-panel/) 或 [notes-desk-widget](notes-desk-widget/) | — |
| **Mac/Win 连 NAS 看待办** | [notes-desk-client](notes-desk-client/) | 本机钉钉桥 |
| **开发者 / 想改代码** | 本仓库完整源码 + [群晖Docker打包与部署](notes-desk-server/docs/群晖Docker打包与部署.md) 自行 build | — |

> **notes-desk-server 源码保留在仓库**，方便二次开发与自行打镜像；**普通用户只需 Releases 里的 `notesdesk-server.tar`**，导入群晖即可。

## 为什么做

macOS 自带「备忘录」桌面小组件**无法完整显示**第一条笔记的正文（固定尺寸、不可滚动）。本项目提供：

- **浮窗版**：可滚动全文、近实时刷新
- **小组件版**：WidgetKit 原生桌面小组件
- **服务端**：群晖 Docker 7×24 运行，钉钉收消息、提醒、Web 管理
- **瘦客户端**：Mac / Windows 连接 NAS API，无需本机钉钉桥

## 子项目与文档

| 目录 | 说明 | 安装文档 |
|------|------|----------|
| [notes-desk-panel](notes-desk-panel/) | 读苹果备忘录的桌面浮窗 | [说明.md](notes-desk-panel/说明.md) |
| [notes-desk-widget](notes-desk-widget/) | WidgetKit 桌面小组件 | [说明.md](notes-desk-widget/说明.md) |
| [notes-desk-server](notes-desk-server/) | 群晖 Docker 服务端 | **[安装与配置指南](notes-desk-server/docs/安装与配置指南.md)** |
| [notes-desk-client](notes-desk-client/) | Mac / Windows 瘦客户端 | [说明.md](notes-desk-client/说明.md) |

### 服务端（群晖）快速路径

1. 从 **GitHub Releases** 下载 `notesdesk-server.tar`（见 [release/README.md](notes-desk-server/release/README.md)）
2. 群晖 `docker load` → 创建容器（挂载 `data` 卷）
3. 浏览器打开 Web → 默认 `admin`/`admin` → 改密码
4. **设置** 里配置 [钉钉](notes-desk-server/docs/钉钉接入指南.md) 与 [大模型](notes-desk-server/docs/安装与配置指南.md#5-配置大模型可选)

（开发者 build 镜像见 [群晖Docker打包与部署.md](notes-desk-server/docs/群晖Docker打包与部署.md)。）

## 架构

```
手机钉钉 ──→ notes-desk-server (群晖 Docker)
                 ├── SQLite
                 ├── 钉钉 Stream + 提醒 + AI 分析
                 └── Web UI

Mac/Win notes-desk-client ──HTTP──→ 同上

notes-desk-panel / notes-desk-widget ──→ 苹果「备忘录」（只读展示）
```

## 配置与安全

**绝不提交真实密钥。** 仅使用各目录下的 `*.example.json` 作为模板：

| 配置 | 模板路径 | 运行时路径（本地/NAS） |
|------|----------|------------------------|
| 钉钉 | `notes-desk-server/config/dingtalk.config.example.json` | `data/config/dingtalk.json` |
| 大模型 | `notes-desk-server/config/llm.config.example.json` | `data/config/llm.json` |

使用者需**自行**在 [钉钉开放平台](https://open.dingtalk.com/) 创建应用并填写 Client ID、Secret、robotCode。

Docker 部署后请：

1. 登录 Web 修改默认密码（初始 `admin` / `admin`）
2. 勿将服务直接暴露公网；建议局域网或反向代理 + HTTPS
3. 钉钉、大模型 API Key 仅保存在自己的 NAS，不要写入公开仓库

## 许可证

MIT — 与 [idemacia/Tools](https://github.com/idemacia/Tools) 仓库一致。
