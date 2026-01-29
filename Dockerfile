FROM node:22-bookworm

# 1. تثبيت Bun و Socat وأدوات النظام
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN corepack enable
WORKDIR /app

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends socat && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# 2. نسخ ملفات المشروع وتثبيت الاعتمادات
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

# 3. نسخ باقي الكود وبناء التطبيق والواجهة
COPY . .
RUN CLAWDBOT_A2UI_SKIP_MISSING=1 pnpm build
ENV CLAWDBOT_PREFER_PNPM=1
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

# 4. إصلاح الصلاحيات (كـ Root)
USER root
RUN mkdir -p /home/node/data /home/node/workspace /app && \
    chown -R node:node /home/node/data /home/node/workspace /app && \
    chmod -R 755 /home/node/data /home/node/workspace /app

# إنشاء ملف الإعدادات في مكان آمن لضمان وثوق البروكسي
RUN echo '{"gateway": {"trustedProxies": ["0.0.0.0/0"], "token": "Medo1996"}}' > /home/node/data/moltbot.json

# 5. إعدادات التشغيل كمستخدم node
USER node
WORKDIR /app

ENV HOST=0.0.0.0
ENV PORT=18789
ENV MOLTBOT_TRUSTED_PROXIES=0.0.0.0/0
ENV CLAWDBOT_STATE_DIR=/home/node/data
ENV CLAWDBOT_WORKSPACE_DIR=/home/node/workspace

# 6. سطر التشغيل النهائي (بدون --config لتجنب الأخطاء)
CMD ["sh", "-c", "socat TCP-LISTEN:18790,fork,bind=0.0.0.0 TCP:127.0.0.1:18789 & node dist/index.js gateway --port 18789 --allow-unconfigured --token Medo1996"]
