FROM node:22-bookworm

# 1. تثبيت الأدوات الأساسية
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN corepack enable
WORKDIR /app

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends socat && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# 2. نسخ ملفات التثبيت
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

# 3. بناء المشروع
COPY . .
RUN CLAWDBOT_A2UI_SKIP_MISSING=1 pnpm build
ENV CLAWDBOT_PREFER_PNPM=1
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

# 4. ضبط المجلدات والصلاحيات (Root)
USER root
RUN mkdir -p /home/node/data /home/node/workspace /app && \
    chown -R node:node /home/node/data /home/node/workspace /app && \
    chmod -R 755 /home/node/data /home/node/workspace /app

# 5. الإعدادات والتشغيل (Node)
USER node
WORKDIR /app

# متغيرات البيئة
ENV HOST=0.0.0.0
ENV PORT=18789
ENV CLAWDBOT_STATE_DIR=/home/node/data
ENV CLAWDBOT_WORKSPACE_DIR=/home/node/workspace

# سطر التشغيل الذكي: يقوم بإنشاء ملف الإعدادات لحظة البدء ثم تشغيل البوت
CMD ["sh", "-c", "echo '{\"gateway\": {\"trustedProxies\": [\"0.0.0.0/0\"], \"token\": \"Medo1996\"}}' > /home/node/data/config.json && socat TCP-LISTEN:18790,fork,bind=0.0.0.0 TCP:127.0.0.1:18789 & node dist/index.js gateway --port 18789 --allow-unconfigured --token Medo1996"]
