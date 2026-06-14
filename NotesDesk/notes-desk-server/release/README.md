# NotesDesk Server — 预构建 Docker 镜像

> **普通用户入口**：下载 tar → 导入群晖 → 读 [安装与配置指南](../docs/安装与配置指南.md)。  
> 本目录源码供开发者 build；**你不需要为了使用而去读 src/ 下的代码。**

## 下载

从 GitHub Releases 下载（与 [idemacia/Tools](https://github.com/idemacia/Tools) 同仓库发布）：

| 文件 | 说明 |
|------|------|
| `notesdesk-server.tar` | linux/amd64 镜像，适用于多数 x86 群晖 |
| `notesdesk-server.tar.gz` | 同上（压缩版，可选） |

> 镜像约 200MB+，**不要**放进 Git 源码树，请用 **Releases 附件** 分发。

## 导入（群晖）

```bash
sudo docker load -i notesdesk-server.tar
sudo docker images notesdesk-server
```

## 运行

```bash
sudo mkdir -p /volume1/docker/notesdesk/data/config
sudo chown -R 999:999 /volume1/docker/notesdesk/data

sudo docker run -d \
  --name notesdesk \
  --restart unless-stopped \
  -p 17887:8080 \
  -e TZ=Asia/Shanghai \
  -e DATA_DIR=/data \
  -v /volume1/docker/notesdesk/data:/data \
  notesdesk-server:latest
```

## 后续配置

导入并启动后，请阅读：

- [../docs/安装与配置指南.md](../docs/安装与配置指南.md) — Web 登录、钉钉、大模型
- [../docs/钉钉接入指南.md](../docs/钉钉接入指南.md) — 开放平台逐步说明

## 维护者：如何生成 tar 并发布

在 Mac 上（Apple Silicon 需指定 amd64）：

```bash
cd notes-desk-server
docker buildx build --platform linux/amd64 -t notesdesk-server:latest --load .
docker save notesdesk-server:latest -o notesdesk-server.tar
```

上传到 [GitHub Releases](https://github.com/idemacia/Tools/releases)（**不要** `git add` tar 进仓库）。
