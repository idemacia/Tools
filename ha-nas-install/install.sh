#!/bin/bash
# 在群晖上分步安装 Home Assistant Container。
# 不修改 Docker 全局配置。已有 Mosquitto 则复用；没有则询问是否安装。密码不写入文件。
# 用法：sudo bash install.sh [--yes]

set -euo pipefail

ASSUME_YES=0
if [[ "${1:-}" == "--yes" ]]; then
  ASSUME_YES=1
elif [[ -n "${1:-}" ]]; then
  echo "未知参数：$1"
  echo "用法：sudo bash install.sh [--yes]"
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

: "${HA_VERSION:?sources.env 缺少 HA_VERSION}"
: "${INSTALL_DIR:?sources.env 缺少 INSTALL_DIR}"
: "${TZ:?sources.env 缺少 TZ}"
: "${CONTAINER_NAME:?sources.env 缺少 CONTAINER_NAME}"
: "${HOST_PORT:?sources.env 缺少 HOST_PORT}"
REVERSE_PROXY_HTTPS_PORT="${REVERSE_PROXY_HTTPS_PORT:-}"
: "${HACS_VERSION:?sources.env 缺少 HACS_VERSION}"

HA_IMAGE="${HA_IMAGE:-}"
HA_IMAGE_TAR="${HA_IMAGE_TAR:-}"
HACS_ZIP="${HACS_ZIP:-}"
HACS_URL="${HACS_URL:-}"
HACS_WECHAT_ACCOUNT="${HACS_WECHAT_ACCOUNT:-智能家居报告}"
HACS_WECHAT_KEYWORD="${HACS_WECHAT_KEYWORD:-HACS}"
HACS_SHA256="${HACS_SHA256:-}"
IMAGE_TAR_SHA256="${IMAGE_TAR_SHA256:-}"
EXPECTED_IMAGE_DIGEST="${EXPECTED_IMAGE_DIGEST:-}"
MOSQUITTO_DIR="${MOSQUITTO_DIR:-/volume1/docker/mosquitto}"
MOSQUITTO_CONTAINER="${MOSQUITTO_CONTAINER:-mosquitto}"
MOSQUITTO_PORT="${MOSQUITTO_PORT:-1883}"
MOSQUITTO_IMAGE="${MOSQUITTO_IMAGE:-}"
MOSQUITTO_IMAGE_TAR="${MOSQUITTO_IMAGE_TAR:-}"

DOCKER=()
COMPOSE=()
LOADED_IMAGE=""
MOSQUITTO_PRESENT=0
STEP=0
TOTAL=9

die() {
  echo ""
  echo "失败：$*"
  exit 1
}

info() {
  echo "$*" >&2
}

step_banner() {
  STEP=$((STEP + 1))
  echo ""
  echo "========================================"
  echo "步骤 ${STEP}/${TOTAL}  $1"
  echo "========================================"
}

# 回车继续。第二个参数为 skip 时允许输入 s。
pause() {
  local title="$1"
  local allow_skip="${2:-}"
  if [[ "$ASSUME_YES" == "1" ]]; then
    info "已使用 --yes，继续：${title}"
    return 0
  fi
  local hint="回车继续"
  if [[ "$allow_skip" == "skip" ]]; then
    hint="回车继续 / s 跳过"
  fi
  local reply
  read -r -p "${hint}，q 退出 > " reply || true
  case "${reply}" in
    q|Q) echo "已退出。已写好的文件不会自动删除。"; exit 0 ;;
    s|S)
      if [[ "$allow_skip" == "skip" ]]; then
        return 1
      fi
      die "这一步不能跳过。"
      ;;
  esac
  return 0
}

confirm_no() {
  local prompt="$1"
  if [[ "$ASSUME_YES" == "1" ]]; then
    echo "需要人工确认，--yes 不会自动答应：${prompt}"
    return 1
  fi
  local reply
  read -r -p "${prompt} [y/N] > " reply || true
  [[ "${reply}" =~ ^[Yy]$ ]]
}

resolve_path() {
  local path="$1"
  if [[ -z "$path" ]]; then
    echo ""
    return
  fi
  if [[ "$path" = /* ]]; then
    echo "$path"
  else
    echo "$BASE_DIR/$path"
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

pick_docker() {
  if docker info >/dev/null 2>&1; then
    DOCKER=(docker)
    return
  fi
  if need_cmd sudo && sudo docker info >/dev/null 2>&1; then
    DOCKER=(sudo docker)
    return
  fi
  die "当前用户无法访问 Docker。请用 ssh 登录 NAS 后执行：sudo bash install.sh"
}

pick_compose() {
  if "${DOCKER[@]}" compose version >/dev/null 2>&1; then
    COMPOSE=("${DOCKER[@]}" compose)
    return
  fi
  if need_cmd docker-compose && docker-compose version >/dev/null 2>&1; then
    if [[ "${DOCKER[0]}" == "sudo" ]]; then
      COMPOSE=(sudo docker-compose)
    else
      COMPOSE=(docker-compose)
    fi
    return
  fi
  if need_cmd sudo && sudo docker-compose version >/dev/null 2>&1; then
    COMPOSE=(sudo docker-compose)
    return
  fi
  die "找不到 docker compose，也找不到 docker-compose。群晖请先安装 Container Manager。"
}

check_sha256() {
  local file="$1"
  local expected="$2"
  local label="$3"
  if [[ -z "$expected" ]]; then
    info "${label} 未配置 SHA256，跳过校验。"
    return
  fi
  need_cmd shasum || die "配置了 SHA256，但系统没有 shasum。"
  local actual
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    die "${label} SHA256 不一致。期望 ${expected}，实际 ${actual}"
  fi
  info "${label} SHA256 一致。"
}

port_in_use() {
  local port="$1"
  if need_cmd ss && ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "[.:]${port}$"; then
    return 0
  fi
  if need_cmd netstat && netstat -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "[.:]${port}$"; then
    return 0
  fi
  return 1
}

verify_image_digest() {
  local image="$1"
  if [[ -z "$EXPECTED_IMAGE_DIGEST" ]]; then
    info "未配置 EXPECTED_IMAGE_DIGEST，跳过摘要核对。"
    return
  fi
  local want="${EXPECTED_IMAGE_DIGEST#sha256:}"
  local digests
  digests="$("${DOCKER[@]}" image inspect --format '{{range .RepoDigests}}{{.}}{{"\n"}}{{end}}' "$image" 2>/dev/null || true)"
  if [[ -z "${digests//[[:space:]]/}" ]]; then
    info "这个镜像没有 RepoDigests（常见于 docker save / docker load）。"
    info "无法在 NAS 上把它和文档中的 Manifest Digest 自动比对：${EXPECTED_IMAGE_DIGEST}"
    info "请确认 tar 来自 ghcr.io/home-assistant/home-assistant:${HA_VERSION}。"
    return
  fi
  if echo "$digests" | grep -q "$want"; then
    info "镜像摘要与文档记录一致：${EXPECTED_IMAGE_DIGEST}"
    return
  fi
  echo "镜像摘要与 sources.env 中的记录不一致。"
  echo "期望：${EXPECTED_IMAGE_DIGEST}"
  echo "实际："
  echo "$digests"
  confirm_no "仍然使用这个镜像？" || die "已停止。请更换镜像或更新 EXPECTED_IMAGE_DIGEST。"
}

write_compose() {
  local image="$1"
  local env_file="$INSTALL_DIR/.env"
  local compose_file="$INSTALL_DIR/compose.yaml"
  local stamp
  stamp="$(date +%Y%m%d%H%M%S)"

  if [[ -f "$compose_file" ]]; then
    cp "$compose_file" "${compose_file}.bak.${stamp}"
    info "已备份原 compose：${compose_file}.bak.${stamp}"
  fi
  if [[ -f "$env_file" ]]; then
    cp "$env_file" "${env_file}.bak.${stamp}"
    info "已备份原 .env：${env_file}.bak.${stamp}"
  fi

  cat >"$env_file" <<EOF
HA_IMAGE=${image}
HA_CONFIG_DIR=${INSTALL_DIR}/config
TZ=${TZ}
HA_VERSION=${HA_VERSION}
EOF

  # 写成具体值，避免 docker-compose v1 与 v2 对环境变量插值的差异。
  cat >"$compose_file" <<EOF
version: "3.8"
services:
  homeassistant:
    container_name: ${CONTAINER_NAME}
    image: "${image}"
    network_mode: host
    restart: unless-stopped
    volumes:
      - ${INSTALL_DIR}/config:/config
    environment:
      TZ: ${TZ}
EOF

  info "已写入 ${compose_file}"
  info "已写入 ${env_file}"
}

write_ha_http_config() {
  local cfg="${INSTALL_DIR}/config/configuration.yaml"
  if [[ -f "$cfg" ]]; then
    if grep -Eq "^[[:space:]]*server_port:[[:space:]]*${HOST_PORT}[[:space:]]*$" "$cfg"; then
      info "已有 configuration.yaml，HTTP 端口是 ${HOST_PORT}。"
      return
    fi
    echo "已存在 ${cfg}，其中没有 server_port: ${HOST_PORT}。"
    echo "host 网络下，Home Assistant 会直接监听群晖上的这个端口。"
    confirm_no "仍然继续？" || die "已停止。请先在 configuration.yaml 里写上 server_port: ${HOST_PORT}。"
    return
  fi
  cat >"$cfg" <<EOF
default_config:

http:
  server_port: ${HOST_PORT}
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - ::1
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.0.0/16
EOF
  info "已写入 ${cfg}，Home Assistant 将监听 ${HOST_PORT}。"
}

mosquitto_container_exists() {
  "${DOCKER[@]}" ps -a --format '{{.Names}}' | grep -qx "$MOSQUITTO_CONTAINER"
}

ask_yes() {
  local prompt="$1"
  if [[ "$ASSUME_YES" == "1" ]]; then
    echo "--yes 不代为选择：${prompt}"
    echo "需要这项时，请去掉 --yes 后重新运行。"
    return 1
  fi
  local reply
  read -r -p "${prompt} [y/N] > " reply || true
  [[ "${reply}" =~ ^[Yy]$ ]]
}

load_or_pull_image() {
  local tar_path="$1"
  local image_ref="$2"
  local label="$3"
  local tar_resolved load_out loaded
  tar_resolved="$(resolve_path "$tar_path")"
  if [[ -n "$tar_resolved" && -f "$tar_resolved" ]]; then
    info "加载 ${label}：${tar_resolved}"
    load_out="$("${DOCKER[@]}" load -i "$tar_resolved")"
    echo "$load_out"
    loaded="$(printf '%s\n' "$load_out" | sed -n 's/^Loaded image: //p' | tail -n 1)"
    if [[ -z "$loaded" ]]; then
      die "docker load 没有打印 ${label} 的镜像名。请重新 docker save 一个带标签的镜像。"
    fi
    printf '%s\n' "$loaded"
    return
  fi
  if [[ -n "$image_ref" ]]; then
    info "拉取 ${label}：${image_ref}"
    info "只使用这条镜像名，不修改 NAS 的 Docker 注册表。"
    "${DOCKER[@]}" pull "$image_ref"
    printf '%s\n' "$image_ref"
    return
  fi
  die "没有找到 ${label} 镜像。请放入 tar，或在 sources.env 里填写镜像地址。"
}

install_mosquitto() {
  local image user pass pass2
  if mosquitto_container_exists || port_in_use "$MOSQUITTO_PORT"; then
    die "端口 ${MOSQUITTO_PORT} 或容器 ${MOSQUITTO_CONTAINER} 已经存在，停止安装第二套 Mosquitto。"
  fi
  if [[ -e "${MOSQUITTO_DIR}/config/mosquitto.conf" || -e "${MOSQUITTO_DIR}/config/pwfile.conf" ]]; then
    die "已存在 ${MOSQUITTO_DIR}/config 里的配置或密码文件。请先确认目录内容，脚本不会覆盖它。"
  fi

  image="$(load_or_pull_image "$MOSQUITTO_IMAGE_TAR" "$MOSQUITTO_IMAGE" "Mosquitto")"
  read -r -p "MQTT 用户名 > " user || true
  if [[ -z "$user" || "$user" == *" "* || "$user" == *:* ]]; then
    die "用户名不能为空，也不能包含空格或冒号。"
  fi
  read -r -s -p "MQTT 密码 > " pass || true
  echo
  read -r -s -p "再输入一次密码 > " pass2 || true
  echo
  if [[ -z "$pass" || "$pass" != "$pass2" ]]; then
    die "两次密码不一致，或密码为空。密码没有写入文件。"
  fi

  mkdir -p "${MOSQUITTO_DIR}/config" "${MOSQUITTO_DIR}/data" "${MOSQUITTO_DIR}/log"
  date -u +%Y-%m-%dT%H:%M:%SZ > "${MOSQUITTO_DIR}/.ha-nas-install"
  cat >"${MOSQUITTO_DIR}/config/mosquitto.conf" <<EOF
listener ${MOSQUITTO_PORT}
allow_anonymous false
password_file /mosquitto/config/pwfile.conf
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
EOF

  printf '%s\n%s\n' "$pass" "$pass" | "${DOCKER[@]}" run --rm -i \
    -v "${MOSQUITTO_DIR}/config:/mosquitto/config" \
    "$image" \
    mosquitto_passwd -c /mosquitto/config/pwfile.conf "$user"
  unset pass pass2

  chown 1883:1883 \
    "${MOSQUITTO_DIR}/config" \
    "${MOSQUITTO_DIR}/config/mosquitto.conf" \
    "${MOSQUITTO_DIR}/config/pwfile.conf" \
    "${MOSQUITTO_DIR}/data" \
    "${MOSQUITTO_DIR}/log"
  chmod 700 "${MOSQUITTO_DIR}/config" "${MOSQUITTO_DIR}/data" "${MOSQUITTO_DIR}/log"
  chmod 600 "${MOSQUITTO_DIR}/config/mosquitto.conf" "${MOSQUITTO_DIR}/config/pwfile.conf"

  cat >"${MOSQUITTO_DIR}/compose.yaml" <<EOF
version: "3.8"
services:
  mosquitto:
    container_name: ${MOSQUITTO_CONTAINER}
    image: "${image}"
    restart: unless-stopped
    ports:
      - "${MOSQUITTO_PORT}:${MOSQUITTO_PORT}"
    volumes:
      - ${MOSQUITTO_DIR}/config:/mosquitto/config
      - ${MOSQUITTO_DIR}/data:/mosquitto/data
      - ${MOSQUITTO_DIR}/log:/mosquitto/log
EOF

  (
    "${COMPOSE[@]}" -f "${MOSQUITTO_DIR}/compose.yaml" up -d
  )
  info "Mosquitto 已启动。用户 ${user}，端口 ${MOSQUITTO_PORT}，匿名登录已关闭。"
  info "密码只保存在 ${MOSQUITTO_DIR}/config/pwfile.conf，没有写入 sources.env。"
}

is_zip() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local magic
  magic="$(head -c 2 "$file" || true)"
  [[ "$magic" == "PK" ]]
}

hacs_download_failed() {
  local dest="$1"
  rm -f "$dest"
  echo ""
  echo "无法从 GitHub 下载 HACS："
  echo "  ${HACS_URL}"
  echo "请关注微信公众号「${HACS_WECHAT_ACCOUNT}」，发送关键词 ${HACS_WECHAT_KEYWORD}。"
  echo "公众号会回复百度云链接。下载后把文件保存为："
  echo "  ${dest}"
  echo "然后重新运行本脚本。"
  exit 1
}

download_hacs() {
  local url="$1"
  local dest="$2"
  local origin sharing_id file_name cookie_jar base file_url
  origin="$(printf '%s' "$url" | sed -E 's|(https?://[^/]+).*|\1|')"
  sharing_id="$(printf '%s' "$url" | sed -nE 's|.*/fsdownload/([^/]+)/.*|\1|p')"
  file_name="$(printf '%s' "$url" | sed -E 's|.*/||')"
  if [[ -z "$sharing_id" ]]; then
    info "从 GitHub 下载 ${url}"
    if ! curl -fL --retry 2 --connect-timeout 30 --max-time 300 -o "$dest" "$url"; then
      hacs_download_failed "$dest"
    fi
  else
    info "这是群晖分享地址。先访问分享页取得 cookie，再下载 zip。"
    info "NAS 访问自己的 QuickConnect 域名经常 404，会再试本机 DSM 的 5000/5001。"
    local downloaded=0
    for base in "$origin" "http://127.0.0.1:5000" "https://127.0.0.1:5001"; do
      cookie_jar="$(mktemp)"
      info "尝试 ${base}/sharing/${sharing_id}"
      if curl -kfsS --connect-timeout 10 --max-time 30 -c "$cookie_jar" -o /dev/null \
        "${base}/sharing/${sharing_id}"; then
        file_url="${base}/fsdownload/${sharing_id}/${file_name}"
        if curl -kfL --retry 2 --connect-timeout 30 --max-time 300 -b "$cookie_jar" -c "$cookie_jar" \
          -o "$dest" "$file_url" && is_zip "$dest"; then
          downloaded=1
          rm -f "$cookie_jar"
          info "已从 ${file_url} 下载。"
          break
        fi
      fi
      rm -f "$cookie_jar" "$dest"
    done
    if [[ "$downloaded" != "1" ]]; then
      hacs_download_failed "$dest"
    fi
    return
  fi
  if ! is_zip "$dest"; then
    hacs_download_failed "$dest"
  fi
}

extract_zip() {
  local zip="$1"
  local dest="$2"
  if need_cmd unzip; then
    unzip -q -o "$zip" -d "$dest"
    return
  fi
  if need_cmd python3; then
    python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$zip" "$dest"
    return
  fi
  if [[ -z "${LOADED_IMAGE:-}" ]]; then
    die "系统没有 unzip 或 python3，且还没有 Home Assistant 镜像，无法解压 HACS。"
  fi
  info "系统没有 unzip，改用镜像 ${LOADED_IMAGE} 里的 Python 解压。"
  "${DOCKER[@]}" run --rm --entrypoint python3 \
    -v "$zip":/hacs.zip:ro \
    -v "$dest":/out \
    "$LOADED_IMAGE" \
    -c 'import zipfile; zipfile.ZipFile("/hacs.zip").extractall("/out")'
}

install_hacs_zip() {
  local zip="$1"
  local dest="$INSTALL_DIR/config/custom_components/hacs"
  mkdir -p "$dest"
  local tmp
  tmp="$(mktemp -d)"
  extract_zip "$zip" "$tmp"

  if [[ -f "$tmp/custom_components/hacs/manifest.json" ]]; then
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    mv "$tmp/custom_components/hacs" "$dest"
  elif [[ -f "$tmp/hacs/manifest.json" ]]; then
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    mv "$tmp/hacs" "$dest"
  elif [[ -f "$tmp/manifest.json" ]]; then
    find "$dest" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    mv "$tmp"/* "$dest"/
  else
    rm -rf "$tmp"
    die "无法识别 hacs.zip 的目录结构，未写入 ${dest}。"
  fi
  rm -rf "$tmp"
  [[ -f "$dest/manifest.json" ]] || die "HACS 解压后没有 manifest.json。"
  info "HACS 已放到 ${dest}"
}

valid_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -ge 1 && "$1" -le 65535 ]]
}

ask_install_settings() {
  local reply
  if [[ "$ASSUME_YES" == "1" ]]; then
    valid_port "$HOST_PORT" || die "HTTP 端口必须是 1 到 65535 的数字。"
    if [[ -n "$REVERSE_PROXY_HTTPS_PORT" ]]; then
      valid_port "$REVERSE_PROXY_HTTPS_PORT" || die "反向代理端口必须是 1 到 65535 的数字。"
      if [[ "$HOST_PORT" == "$REVERSE_PROXY_HTTPS_PORT" ]]; then
        die "HTTP 端口和反向代理端口不能相同。两个服务都要占用群晖上的端口。"
      fi
    fi
    return
  fi
  echo "直接回车会使用括号中的默认值。默认按第一次安装来填写。"
  read -r -p "Home Assistant 的 HTTP 端口 [${HOST_PORT}] > " reply || true
  if [[ -n "$reply" ]]; then
    HOST_PORT="$reply"
  fi
  valid_port "$HOST_PORT" || die "HTTP 端口必须是 1 到 65535 的数字。"

  local proxy_default="${REVERSE_PROXY_HTTPS_PORT:--}"
  read -r -p "反向代理的外部 HTTPS 端口，不需要请输入 - [${proxy_default}] > " reply || true
  if [[ -n "$reply" ]]; then
    if [[ "$reply" == "-" ]]; then
      REVERSE_PROXY_HTTPS_PORT=""
    else
      REVERSE_PROXY_HTTPS_PORT="$reply"
    fi
  fi
  if [[ -n "$REVERSE_PROXY_HTTPS_PORT" ]]; then
    valid_port "$REVERSE_PROXY_HTTPS_PORT" || die "反向代理端口必须是 1 到 65535 的数字。"
    if [[ "$HOST_PORT" == "$REVERSE_PROXY_HTTPS_PORT" ]]; then
      die "HTTP 端口和反向代理端口不能相同。两个服务都要占用群晖上的端口。"
    fi
  fi
}

echo "Home Assistant 分步安装"
echo "安装包目录：${BASE_DIR}"
ask_install_settings

echo "目标目录：${INSTALL_DIR}"
echo "容器名：${CONTAINER_NAME}"
echo "版本：${HA_VERSION}    时区：${TZ}"
echo "HTTP 端口：${HOST_PORT}"
if [[ -n "$REVERSE_PROXY_HTTPS_PORT" ]]; then
  echo "反向代理：外部 HTTPS ${REVERSE_PROXY_HTTPS_PORT} → http://127.0.0.1:${HOST_PORT}"
else
  echo "不配置反向代理。安装后用 http://群晖IP:${HOST_PORT} 访问。"
fi
echo "不会修改 /etc/docker/daemon.json。已有 Mosquitto 会复用；没有时才会询问是否安装。"

step_banner "检查 Docker"
info "确认本机能运行容器，并选择实际存在的 compose 命令。"
pause "检查 Docker"
pick_docker
pick_compose
info "Docker 命令：${DOCKER[*]}"
info "Compose 命令：${COMPOSE[*]}"
"${DOCKER[@]}" version --format 'Docker {{.Server.Version}}' 2>/dev/null || "${DOCKER[@]}" version
"${COMPOSE[@]}" version

step_banner "检查端口与已有容器"
info "检查 HTTP ${HOST_PORT} 是否已经有程序在监听。"
info "同时检查有没有名为 ${MOSQUITTO_CONTAINER} 的容器，或 ${MOSQUITTO_PORT} 是否已在监听。"
pause "检查端口与容器"

if port_in_use "$HOST_PORT"; then
  echo "端口 ${HOST_PORT} 已在监听。脚本不列出其他容器。"
  confirm_no "仍然继续？只有确认占用者就是即将重建的 Home Assistant 才应选 y。" \
    || die "请换一个 HTTP 端口后重新运行。"
else
  info "未发现 ${HOST_PORT} 处于监听。"
fi

echo ""
if mosquitto_container_exists || port_in_use "$MOSQUITTO_PORT"; then
  MOSQUITTO_PRESENT=1
  info "已有 Mosquitto 或 ${MOSQUITTO_PORT} 端口已在监听，本次不安装第二套。"
  "${DOCKER[@]}" ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -i "$MOSQUITTO_CONTAINER" || true
else
  info "没有检测到容器 ${MOSQUITTO_CONTAINER}，端口 ${MOSQUITTO_PORT} 也没有在监听。"
fi

if "${DOCKER[@]}" ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "已存在名为 ${CONTAINER_NAME} 的容器。继续的话会由 compose 按新配置重建它。"
  confirm_no "重建已有的 ${CONTAINER_NAME}？" || die "已停止，未改动该容器。"
fi

step_banner "准备 Home Assistant 镜像"
info "国内从 ghcr.io 拉大镜像会很慢。优先使用 assets 里的 tar。"
pause "准备镜像"

IMAGE_TAR_PATH="$(resolve_path "$HA_IMAGE_TAR")"
if [[ -n "$IMAGE_TAR_PATH" && -f "$IMAGE_TAR_PATH" ]]; then
  check_sha256 "$IMAGE_TAR_PATH" "$IMAGE_TAR_SHA256" "镜像 tar"
  info "加载 ${IMAGE_TAR_PATH}"
  load_out="$("${DOCKER[@]}" load -i "$IMAGE_TAR_PATH")"
  echo "$load_out"
  LOADED_IMAGE="$(echo "$load_out" | sed -n 's/^Loaded image: //p' | tail -n 1)"
  if [[ -z "$LOADED_IMAGE" ]]; then
    die "docker load 没有打印镜像名。请重新 docker save 一个带标签的镜像。"
  fi
  info "将使用镜像：${LOADED_IMAGE}"
elif [[ -n "$HA_IMAGE" ]]; then
  info "拉取 ${HA_IMAGE}"
  info "只使用这条镜像名，不修改 NAS 的 Docker 注册表或 /etc/docker/daemon.json。"
  "${DOCKER[@]}" pull "$HA_IMAGE"
  LOADED_IMAGE="$HA_IMAGE"
else
  die "没有找到镜像。请把 docker save 的包放到 ${IMAGE_TAR_PATH}，或在 sources.env 设置 HA_IMAGE。"
fi

verify_image_digest "$LOADED_IMAGE"

step_banner "写入 Compose"
info "目录：${INSTALL_DIR}"
info "网络：host。端口由 configuration.yaml 的 server_port 决定，不能靠 Docker 端口映射。"
info "配置卷：${INSTALL_DIR}/config → /config"
info "HTTP 端口 ${HOST_PORT}。host 网络下，这就是群晖上的监听端口。"
pause "写入 compose.yaml"
mkdir -p "${INSTALL_DIR}/config"
write_ha_http_config
write_compose "$LOADED_IMAGE"

step_banner "启动 Home Assistant"
info "执行 compose up -d。首次启动会在 config 目录生成初始文件。"
pause "启动容器"
(
  "${COMPOSE[@]}" -f "$INSTALL_DIR/compose.yaml" up -d
)
"${DOCKER[@]}" ps --filter "name=^/${CONTAINER_NAME}$" --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

step_banner "等待网页端口"
info "等待 http://127.0.0.1:${HOST_PORT} 有响应。首次初始化可能要几分钟。"
if pause "等待端口" skip; then
  if ! need_cmd curl; then
    info "系统没有 curl，跳过自动探测。请稍后自己打开 http://<NAS IP>:${HOST_PORT}"
  else
    ready=0
    for _ in $(seq 1 90); do
      code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 "http://127.0.0.1:${HOST_PORT}" || true)"
      case "$code" in
        200|201|302|401|405)
          info "端口已响应，HTTP ${code}。"
          ready=1
          break
          ;;
      esac
      sleep 2
    done
    if [[ "$ready" != "1" ]]; then
      echo "约 3 分钟内端口还没有 HTTP 响应。容器日志："
      "${DOCKER[@]}" logs --tail 40 "$CONTAINER_NAME" || true
      echo "可以等一会儿再打开 http://<NAS IP>:${HOST_PORT} 。安装不会因此回滚。"
    fi
  fi
else
  info "已跳过等待。"
fi

step_banner "安装 HACS"
info "HACS ${HACS_VERSION} 解压到 ${INSTALL_DIR}/config/custom_components/hacs"
info "没有本地 zip 时，从 ${HACS_URL} 下载。"
if ! pause "安装 HACS" skip; then
  info "已跳过 HACS。"
else
  HACS_ZIP_PATH="$(resolve_path "$HACS_ZIP")"
  if [[ ! -f "$HACS_ZIP_PATH" ]]; then
    if [[ -z "$HACS_URL" ]]; then
      hacs_download_failed "$HACS_ZIP_PATH"
    fi
    need_cmd curl || die "需要 curl 才能下载 HACS。"
    mkdir -p "$(dirname "$HACS_ZIP_PATH")"
    info "下载 ${HACS_URL}"
    download_hacs "$HACS_URL" "$HACS_ZIP_PATH"
  fi
  check_sha256 "$HACS_ZIP_PATH" "$HACS_SHA256" "HACS zip"
  install_hacs_zip "$HACS_ZIP_PATH"
  info "重启容器，让 HA 加载 custom_components。"
  "${DOCKER[@]}" restart "$CONTAINER_NAME"
fi

step_banner "检查并按需安装 Mosquitto"
if [[ "$MOSQUITTO_PRESENT" == "1" ]]; then
  info "沿用现有 Broker，不创建新的 Mosquitto。"
  pause "确认沿用现有 Mosquitto"
else
  info "当前机器没有可用的 Mosquitto。"
  info "选择安装时，会新建容器 ${MOSQUITTO_CONTAINER}，目录 ${MOSQUITTO_DIR}，端口 ${MOSQUITTO_PORT}，并关闭匿名登录。"
  info "国内拉取 Docker Hub 上的 eclipse-mosquitto 可能很慢，可以事先放入镜像 tar，或使用 sources.env 里的镜像地址。"
  if ask_yes "是否安装 Mosquitto？"; then
    install_mosquitto
    MOSQUITTO_PRESENT=1
  else
    info "已跳过 Mosquitto。Home Assistant 仍会安装，MQTT 集成需要以后另备 Broker。"
  fi
fi

step_banner "安装结果与仍需手工完成的部分"
"${DOCKER[@]}" ps --filter "name=^/${CONTAINER_NAME}$" --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' || true
echo ""
echo "Home Assistant 容器已经启动："
echo "  配置目录  ${INSTALL_DIR}/config"
echo "  Compose   ${INSTALL_DIR}/compose.yaml"
echo "  请在电脑浏览器打开  http://群晖的局域网IP:${HOST_PORT}"
echo ""
echo "127.0.0.1 表示正在打开浏览器的那台设备。在自己的电脑上访问 127.0.0.1 不会连到群晖。"
echo "如果电脑开了代理或科学上网，请把局域网网段加入直连，否则群晖的局域网 IP 可能打不开。"
echo ""
echo "请在 5 分钟内打开上面的地址。Home Assistant 会把新的 HTTP 端口当作待确认配置，"
echo "超时未确认就会退回 8123 并重启。8123 若已被占用，这个实例会无法启动。"
echo ""
echo "接下来请在网页里完成："
echo "  1. 创建所有者账户。"
echo "  2. 若安装了 HACS：设置 → 设备与服务 → 添加集成 → HACS，完成 GitHub 授权。"
if [[ -n "$REVERSE_PROXY_HTTPS_PORT" ]]; then
  echo "  3. 群晖反向代理：外部 HTTPS ${REVERSE_PROXY_HTTPS_PORT} → http://127.0.0.1:${HOST_PORT}，并打开 WebSocket。"
else
  echo "  3. 如需用域名访问：在群晖反向代理中把外部 HTTPS 指到 http://127.0.0.1:${HOST_PORT}，并打开 WebSocket。外部端口不要和 ${HOST_PORT} 相同。"
fi
echo "  4. 为该网站配置证书，再在 Home Assistant 里开启多因素认证。"
if [[ "$MOSQUITTO_PRESENT" == "1" ]]; then
  echo "  5. 在 HA 里添加 MQTT 集成。Broker 用 NAS 的 ${MOSQUITTO_PORT}，使用已有账号。不要再起一套 Mosquitto。"
else
  echo "  5. 这次没有安装 Mosquitto。需要 MQTT 时，重新运行脚本并选择安装，或使用自己的 Broker。"
fi
echo "  6. 做一次完整备份。然后做 NAS 重启恢复测试。"
echo ""
echo "查看日志：${DOCKER[*]} logs -f ${CONTAINER_NAME}"
