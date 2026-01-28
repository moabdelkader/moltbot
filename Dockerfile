FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# تثبيت الحزم المطلوبة وأداة socat للربط الشبكي
ARG CLAWDBOT_DOCKER_APT_PACKAGES="socat"
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $CLAWDBOT_DOCKER_APT_PACKAGES && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN CLAWDBOT_A2UI_SKIP_MISSING=1 pnpm build
ENV CLAWDBOT_PREFER_PNPM=1
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

# --- إصلاح الصلاحيات ---
USER root
RUN mkdir -p /home/node/data /home/node/workspace && \
    chown -R node:node /home/node/data /home/node/workspace && \
    chmod -R 755 /home/node/data /home/node/workspace

USER node

ENV HOST=0.0.0.0
ENV PORT=18789
ENV CLAWDBOT_STATE_DIR=/home/node/data
ENV CLAWDBOT_WORKSPACE_DIR=/home/node/workspace

# شرح الـ CMD:
# 1. socat: يفتح منفذ 18790 للعالم الخارجي ويرسل البيانات داخلياً لمنفذ 18789
# 2. node: يشغل البوت كالمعتاد
CMD ["sh", "-c", "socat TCP-LISTEN:18790,fork,bind=0.0.0.0 TCP:127.0.0.1:18789 & node dist/index.js gateway --port 18789 --allow-unconfigured --token 123456789"]
