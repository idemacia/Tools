#!/bin/bash
# 清除 sources.env 里记录的这一次 Home Assistant 安装。
# 不删除没有 .ha-nas-install 标记的 Mosquitto。
# 用法：sudo bash uninstall.sh [--yes]

set -euo pipefail

ASSUME_YES=0
if [[ "${1:-}" == "--yes" ]]; then
  ASSUME_YES=1
elif [[ -n "${1:-}" ]]; then
  echo "未知参数：$1"
  echo "用法：sudo bash uninstall.sh [--yes]"
  exit 1
fi

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCES_FILE="$BASE_DIR/sources.env"

if [[ ! -f "$SOURCES_FILE" ]]; then
  echo "找不到 $SOURCES_FILE"
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$SOURCES_FILE"
set +a

: "${INSTALL_DIR:?sources.env 缺少 INSTALL_DIR}"
: "${CONTAINER_NAME:?sources.env 缺少 CONTAINER_NAME}"
MOSQUITTO_DIR="${MOSQUITTO_DIR:-/volume1/docker/mosquitto}"
MOSQUITTO_CONTAINER="${MOSQUITTO_CONTAINER:-mosquitto}"
HACS_ZIP="${HACS_ZIP:-assets/hacs.zip}"

die() {
  echo ""
  echo "失败：$*"
  exit 1
}

if [[ "$CONTAINER_NAME" == "mosquitto" ]]; then
  die "拒绝把 Home Assistant 容器名设为 mosquitto。"
fi
if [[ "$INSTALL_DIR" != /volume1/docker/* || "$INSTALL_DIR" == "/volume1/docker" || "$INSTALL_DIR" == /volume1/docker/*/* ]]; then
  die "INSTALL_DIR 必须是 /volume1/docker 下的一层目录，当前是 ${INSTALL_DIR}。"
fi
if [[ "$INSTALL_DIR" == "/volume1/docker/mosquitto" ]]; then
  die "拒绝删除 Mosquitto 目录。请只通过安装标记清理本次新建的 Broker。"
fi

DOCKER=()
COMPOSE=()
if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
else
  die "当前用户无法访问 Docker。"
fi
if "${DOCKER[@]}" compose version >/dev/null 2>&1; then
  COMPOSE=("${DOCKER[@]}" compose)
elif command -v docker-compose >/dev/null 2>&1; then
  if [[ "${DOCKER[0]}" == "sudo" ]]; then
    COMPOSE=(sudo docker-compose)
  else
    COMPOSE=(docker-compose)
  fi
elif command -v sudo >/dev/null 2>&1 && sudo docker-compose version >/dev/null 2>&1; then
  COMPOSE=(sudo docker-compose)
else
  COMPOSE=()
fi

echo "将清除这次安装产生的内容："
echo "  容器  ${CONTAINER_NAME}"
echo "  目录  ${INSTALL_DIR}"
if [[ -f "${MOSQUITTO_DIR}/.ha-nas-install" ]]; then
  echo "  容器  ${MOSQUITTO_CONTAINER}（带有本安装包标记）"
  echo "  目录  ${MOSQUITTO_DIR}"
else
  echo "  Mosquitto 没有本安装包标记，不删除。"
fi
HACS_ZIP_PATH="$HACS_ZIP"
if [[ "$HACS_ZIP_PATH" != /* ]]; then
  HACS_ZIP_PATH="$BASE_DIR/$HACS_ZIP_PATH"
fi
if [[ -f "$HACS_ZIP_PATH" ]]; then
  echo "  下载缓存  ${HACS_ZIP_PATH}"
fi
echo "没有安装标记的 Mosquitto 不会删除。"

if [[ "$ASSUME_YES" != "1" ]]; then
  read -r -p "确认清除？[y/N] > " reply || true
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "已取消。"
    exit 0
  fi
fi

remove_container() {
  local name="$1"
  if "${DOCKER[@]}" ps -a --format '{{.Names}}' | grep -qx "$name"; then
    "${DOCKER[@]}" rm -f "$name"
    echo "已删除容器 ${name}"
  else
    echo "没有容器 ${name}"
  fi
}

remove_compose_dir() {
  local dir="$1"
  if [[ -f "${dir}/compose.yaml" && ${#COMPOSE[@]} -gt 0 ]]; then
    "${COMPOSE[@]}" -f "${dir}/compose.yaml" down --remove-orphans || true
  fi
  if [[ -d "$dir" ]]; then
    rm -rf "$dir"
    echo "已删除目录 ${dir}"
  else
    echo "没有目录 ${dir}"
  fi
}

remove_container "$CONTAINER_NAME"
remove_compose_dir "$INSTALL_DIR"

if [[ -f "${MOSQUITTO_DIR}/.ha-nas-install" ]]; then
  remove_container "$MOSQUITTO_CONTAINER"
  remove_compose_dir "$MOSQUITTO_DIR"
fi

if [[ -f "$HACS_ZIP_PATH" ]]; then
  rm -f "$HACS_ZIP_PATH"
  echo "已删除 ${HACS_ZIP_PATH}"
fi

echo ""
echo "清除完成。群晖反向代理规则需要在控制面板里另行删除。"
