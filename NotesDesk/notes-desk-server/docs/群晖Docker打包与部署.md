# 群晖 Docker 打包、导出与部署指南

> NotesDesk Server · Mac 开发机打镜像 → 导出 tar → 群晖导入运行  
> 适用场景：Apple Silicon Mac 为 x86 群晖构建镜像，或 NAS 上 build 较慢/失败时

---

## 1. 整体流程

```
Mac（或 CI）                    群晖 NAS
─────────────                   ─────────
源码 notes-desk-server
    │
    ▼
docker buildx（linux/amd64）
    │
    ▼
notesdesk-server:latest
    │
    ▼
docker save → .tar 文件  ──拷贝──▶  Container Manager 导入镜像
                                      │
                                      ▼
                                 创建容器 + 挂载 data 卷
                                      │
                                      ▼
                              http://<NAS_IP>:17887
```

**要点：**

| 内容 | 存放位置 | 更新镜像是否丢失 |
|------|----------|------------------|
| 程序（后端 + Web） | Docker **镜像内** | 需重新 build |
| 任务库、钉钉配置 | NAS **`data/` 卷** | **不丢失** |

---

## 2. 前提

| 项 | 说明 |
|----|------|
| 开发机 | Mac（Intel / Apple Silicon 均可），已安装 [Docker Desktop](https://www.docker.com/products/docker-desktop/) |
| 群晖 | DSM 7+，已安装 **Container Manager** |
| NAS 架构 | 多数型号为 **linux/amd64**（x86）；ARM 型号需改 `--platform` |
| 网络 | NAS 能访问外网（钉钉 Stream 需出站连接） |
| 钉钉 | 开放平台应用：Client ID、Client Secret、robotCode |

---

## 3. NAS 目录规划（首次部署前）

在群晖 **文件管理器** 或 SSH 中创建：

```
/volume1/docker/notesdesk/
└── data/                          ← 持久化，重建容器不删
    ├── config/
    │   ├── dingtalk.json          ← 钉钉凭证（见下文）
    │   └── llm.json               ← 可选，AI 分析
    ├── store/
    │   └── notesdesk.db           ← 自动创建
    ├── backup/                    ← 可选
    └── logs/                      ← 可选
```

### 3.1 准备 dingtalk.json

复制项目 `config/dingtalk.config.example.json`，放到 NAS：

`/volume1/docker/notesdesk/data/config/dingtalk.json`

```json
{
  "clientId": "你的 AppKey",
  "clientSecret": "你的 AppSecret",
  "robotCode": "机器人编码",
  "reminderUserIds": ["你的 staffId"]
}
```

也可在 Web **设置 → 钉钉连接** 中填写并保存（会写入 `data/config/` 并重启桥）。

### 3.2 数据目录权限（重要）

容器内以非 root 用户运行。若启动报 `SQLITE_CANTOPEN`，在 NAS SSH 执行：

```bash
sudo chown -R 999:999 /volume1/docker/notesdesk/data
sudo chmod -R u+rwX /volume1/docker/notesdesk/data
```

---

## 4. 在 Mac 上打包镜像

进入项目目录：

```bash
cd /path/to/NotesDesk/notes-desk-server
```

### 4.1 方式 A：标准 build（Docker Hub 可访问）

Apple Silicon Mac 必须为群晖指定 **amd64** 平台：

```bash
docker buildx build \
  --platform linux/amd64 \
  -t notesdesk-server:latest \
  --load \
  .
```

Intel Mac 可省略 `--platform linux/amd64`（若 NAS 同为 amd64）。

### 4.2 方式 B：国内网络（Docker Hub 超时）

使用国内 Node 基础镜像与 npm/apt 镜像源：

```bash
docker buildx build \
  --platform linux/amd64 \
  -t notesdesk-server:latest \
  --load \
  --build-arg NODE_IMAGE=docker.1panel.live/library/node:22-bookworm-slim \
  --build-arg NPM_REGISTRY=https://registry.npmmirror.com \
  --build-arg APT_MIRROR=mirrors.aliyun.com \
  .
```

若仍卡在拉基础镜像，可先预拉：

```bash
chmod +x scripts/docker-pull-node.sh
./scripts/docker-pull-node.sh 1    # 失败可试 2 或 3
```

### 4.3 验证镜像

```bash
docker images notesdesk-server
docker run --rm -p 8080:8080 notesdesk-server:latest
# 另开终端：curl http://127.0.0.1:8080/health
# Ctrl+C 停止测试容器
```

---

## 5. 导出镜像为 tar

```bash
docker save notesdesk-server:latest -o notesdesk-server.tar
```

可选压缩（文件较大时）：

```bash
gzip -k notesdesk-server.tar    # 得到 notesdesk-server.tar.gz
```

将 `notesdesk-server.tar`（或 `.tar.gz`）通过 **文件管理器 / SMB / scp** 拷到群晖，例如：

```
/volume1/docker/notesdesk/notesdesk-server.tar
```

**scp 示例：**

```bash
scp notesdesk-server.tar admin@<NAS_IP>:/volume1/docker/notesdesk/
```

---

## 6. 在群晖上导入并部署

### 6.1 导入镜像（Container Manager 图形界面）

1. 打开 **Container Manager** → **镜像** → **新增** → **从文件添加**
2. 选择 `notesdesk-server.tar`（若为 `.gz` 先 `gunzip` 或在 SSH 用 `docker load`）
3. 导入完成后应看到 `notesdesk-server:latest`

**SSH 导入（可选）：**

```bash
sudo docker load -i /volume1/docker/notesdesk/notesdesk-server.tar
sudo docker images | grep notesdesk
```

### 6.2 创建容器

**方式 A：Container Manager 图形界面**

1. **容器** → **创建** → 选择镜像 `notesdesk-server:latest`
2. 容器名称：`notesdesk`
3. **端口设置**：本地端口 `17887` → 容器端口 `8080`  
   （`8080` 若已被占用可改为其他，如 `17887`）
4. **存储空间**（卷挂载）：

   | 容器路径 | 主机路径 |
   |----------|----------|
   | `/data` | `/volume1/docker/notesdesk/data` |

5. **环境变量**（可选）：

   | 变量 | 值 |
   |------|-----|
   | `TZ` | `Asia/Shanghai` |
   | `DATA_DIR` | `/data` |
   | `NOTESDESK_TOKEN` | 自定义 API 令牌（可选） |

6. 启用 **自动重启**，启动容器

**方式 B：SSH 一条命令**

```bash
sudo docker run -d \
  --name notesdesk \
  --restart unless-stopped \
  -p 17887:8080 \
  -e TZ=Asia/Shanghai \
  -e DATA_DIR=/data \
  -v /volume1/docker/notesdesk/data:/data \
  notesdesk-server:latest
```

若设置了 API 令牌，追加：`-e NOTESDESK_TOKEN=你的密钥`

**方式 C：在 NAS 上直接 build（不上传 tar）**

将整个 `notes-desk-server` 源码上传到 NAS 后：

```bash
cd /volume1/docker/notesdesk/notes-desk-server
sudo docker compose -f docker-compose.synology.yml up -d --build
```

需修改 compose 中端口映射为 `17887:8080`（若 8080 冲突）。详见 [群晖部署指南.md](./群晖部署指南.md)。

---

## 7. 验证部署

### 7.1 健康检查

浏览器或 curl：

```
http://<NAS_IP>:17887/health
```

期望：

```json
{"ok":true,"bridge":true,"time":"..."}
```

- `bridge: true` → 钉钉 Stream 已连接
- `bridge: false` → 检查 `data/config/dingtalk.json` 或 Web 设置

### 7.2 Web 界面

```
http://<NAS_IP>:17887
```

左侧 **设置** 可配置钉钉、AI、提醒、**数据导入/导出**。

### 7.3 查看日志

Container Manager → 容器 `notesdesk` → **日志**，或 SSH：

```bash
sudo docker logs -f notesdesk
```

正常应看到类似：

```
[dingtalk-bridge] starting Stream…
[dingtalk-bridge] Socket open
```

### 7.4 测试写入任务

```bash
curl -X POST http://<NAS_IP>:17887/ingest \
  -H 'Content-Type: application/json' \
  -d '{"text":"测试任务","source":"manual"}'
```

---

## 8. 更新版本（改代码后重新部署）

**代码在镜像里**，改后端或 Web 后必须 **重新 build → save → 导入 → 重启容器**。  
**`data/` 卷不变，任务和配置保留。**

### 8.1 Mac 上

```bash
cd notes-desk-server

# 重新 build（同第 4 节）
docker buildx build --platform linux/amd64 -t notesdesk-server:latest --load .

# 重新导出
docker save notesdesk-server:latest -o notesdesk-server.tar

# 拷到 NAS 后 load
```

### 8.2 群晖上

```bash
# 导入新镜像（会覆盖 latest 标签）
sudo docker load -i /volume1/docker/notesdesk/notesdesk-server.tar

# 停止并删除旧容器（不删 data 卷）
sudo docker stop notesdesk
sudo docker rm notesdesk

# 用第 6.2 节相同参数重新 run，或 Container Manager 里「重新创建」
sudo docker run -d \
  --name notesdesk \
  --restart unless-stopped \
  -p 17887:8080 \
  -e TZ=Asia/Shanghai \
  -e DATA_DIR=/data \
  -v /volume1/docker/notesdesk/data:/data \
  notesdesk-server:latest
```

---

## 9. 钉钉与 Mac 桌面版冲突

钉钉 Stream **同一 Client ID 只允许一个连接**。

| 场景 | 做法 |
|------|------|
| 已用 NAS 收钉钉 | **不要**在 Mac 上再运行第二个钉钉 Stream 连接（同一 Client ID 只能连一处） |
| Mac 上仍有残留 bridge 进程 | 结束相关 Node 进程后在 NAS 重启容器 |
| 消息收不到 | 查 NAS 日志是否 `Socket open`；确认 Mac 无第二个 bridge |

架构示意：

```
手机钉钉 → NAS Docker (notesdesk) → SQLite
              ↓
       Web :17887 / 瘦客户端 API
```

---

## 10. 数据备份与迁移

### 10.1 备份

| 方式 | 路径 |
|------|------|
| Hyper Backup | 整个 `/volume1/docker/notesdesk/data` |
| 手动 | `data/store/notesdesk.db` |
| Web 导出 | 设置 → 数据导入/导出 → CSV 或 JSON |

### 10.2 从 Mac 桌面版导入

Web：**设置 → 从 JSON 导入**，或 API：

```bash
curl -X POST http://<NAS_IP>:17887/api/import/tasks \
  -H 'Content-Type: application/json' \
  -d @tasks.json
```

### 10.3 CSV 中文乱码

Excel 双击打开 UTF-8 CSV 可能乱码。可：

- 用 **导出 JSON** 查看；
- Excel：**数据 → 从文本/CSV → 编码选 UTF-8**；
- 新版本镜像已在 CSV 加 UTF-8 BOM，重新部署后双击一般正常。

---

## 11. 常见问题

| 现象 | 原因 / 处理 |
|------|-------------|
| `SQLITE_CANTOPEN` | `sudo chown -R 999:999 /volume1/docker/notesdesk/data` |
| `bridge: false` | 检查 dingtalk.json、凭证、容器日志 |
| 钉钉消息不进 NAS | Mac 上是否还有 `dingtalk-bridge`；NAS 是否 `Socket open` |
| 端口打不开 | 确认映射为 `17887:8080`；群晖防火墙是否放行 |
| Mac build 很慢 | 首次 build 需编译 native 模块；用 `--build-arg` 国内源 |
| 更新后数据没了 | 检查是否误删 `data/` 或未挂载 `-v .../data:/data` |
| API 401 | 设置了 `NOTESDESK_TOKEN`，Web 设置里保存 Token 或带 Bearer 头 |

---

## 12. 命令速查

```bash
# Mac：build + 导出
docker buildx build --platform linux/amd64 -t notesdesk-server:latest --load .
docker save notesdesk-server:latest -o notesdesk-server.tar

# NAS：导入 + 运行
sudo docker load -i notesdesk-server.tar
sudo docker run -d --name notesdesk --restart unless-stopped \
  -p 17887:8080 -e TZ=Asia/Shanghai -e DATA_DIR=/data \
  -v /volume1/docker/notesdesk/data:/data \
  notesdesk-server:latest

# 健康检查
curl http://<NAS_IP>:17887/health

# 日志
sudo docker logs -f notesdesk
```

---

## 13. 相关文档

- [群晖部署指南.md](./群晖部署指南.md) — 群晖 Compose 部署、API、迁移细节
- [../说明.md](../说明.md) — 本地开发与 API 摘要
