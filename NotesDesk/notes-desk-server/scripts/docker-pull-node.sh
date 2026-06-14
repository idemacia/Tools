#!/usr/bin/env bash
# 国内预拉 node 基础镜像，解决 docker compose build 卡在下载层
# 用法：./scripts/docker-pull-node.sh [镜像源编号]
#   1 = docker.1panel.live（默认）
#   2 = docker.xuanyuan.me
#   3 = docker.m.daocloud.io

set -euo pipefail

TAG=node:22-bookworm-slim
CHOICE=${1:-1}

case "$CHOICE" in
  1) MIRROR=docker.1panel.live/library/node:22-bookworm-slim ;;
  2) MIRROR=docker.xuanyuan.me/library/node:22-bookworm-slim ;;
  3) MIRROR=docker.m.daocloud.io/library/node:22-bookworm-slim ;;
  *) echo "未知选项: $1"; exit 1 ;;
esac

echo "拉取: $MIRROR"
docker pull "$MIRROR"
docker tag "$MIRROR" "$TAG"
echo "已标记为 $TAG"
echo ""
echo "接下来执行（不再走外网拉 base 镜像）："
echo "  docker compose -f docker-compose.yml -f docker-compose.cn.local.yml up -d --build"
