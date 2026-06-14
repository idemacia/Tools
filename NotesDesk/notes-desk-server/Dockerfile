# 国内镜像 build 参数（见 docker-compose.cn.yml）
ARG NODE_IMAGE=node:22-bookworm-slim
ARG NPM_REGISTRY=
ARG APT_MIRROR=

FROM ${NODE_IMAGE} AS web-builder

WORKDIR /app/web

COPY web/package.json web/package-lock.json* ./
RUN if [ -n "$NPM_REGISTRY" ]; then npm config set registry "$NPM_REGISTRY"; fi \
  && npm install

COPY web/ ./
RUN npm run build

FROM ${NODE_IMAGE} AS builder

ARG APT_MIRROR=

WORKDIR /app

RUN if [ -n "$APT_MIRROR" ]; then \
      for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list; do \
        [ -f "$f" ] || continue; \
        sed -i "s|deb.debian.org|${APT_MIRROR}|g" "$f"; \
        sed -i "s|security.debian.org|${APT_MIRROR}/debian-security|g" "$f"; \
      done; \
    fi \
  && apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN if [ -n "$NPM_REGISTRY" ]; then npm config set registry "$NPM_REGISTRY"; fi \
  && npm ci

COPY tsconfig.json ./
COPY migrations ./migrations
COPY config ./config
COPY src ./src

RUN npm run build \
  && npm prune --omit=dev

FROM ${NODE_IMAGE} AS runner

WORKDIR /app

ENV NODE_ENV=production \
    DATA_DIR=/data \
    HOST=0.0.0.0 \
    PORT=8080 \
    TZ=Asia/Shanghai

RUN groupadd --system notesdesk \
  && useradd --system --gid notesdesk --home-dir /app notesdesk \
  && mkdir -p /data/config /data/store /data/backup /data/logs \
  && chown -R notesdesk:notesdesk /data /app

COPY --from=builder --chown=notesdesk:notesdesk /app/node_modules ./node_modules
COPY --from=builder --chown=notesdesk:notesdesk /app/dist ./dist
COPY --from=builder --chown=notesdesk:notesdesk /app/migrations ./migrations
COPY --from=builder --chown=notesdesk:notesdesk /app/config ./config
COPY --from=builder --chown=notesdesk:notesdesk /app/package.json ./package.json
COPY --from=web-builder --chown=notesdesk:notesdesk /app/web/dist ./web/dist
COPY --chown=notesdesk:notesdesk scripts ./scripts

USER notesdesk

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8080/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "dist/index.js"]
