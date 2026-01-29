FROM node:22-bookworm

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN corepack enable
WORKDIR /app

# Install socat
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

# --- Permissions Fix ---
USER root
RUN mkdir -p /home/node/data /home/node/workspace && \
    chown -R node:node /home/node/data /home/node/workspace && \
    chmod -R 755 /home/node/data /home/node/workspace

# ... (نفس الجزء العلوي حتى الوصول لـ USER node)

# ... (نفس الجزء العلوي حتى الوصول لـ USER node)

USER node
WORKDIR /home/node/app

# إنشاء المجلدات وضمان وجودها
RUN mkdir -p /home/node/data

# إنشاء ملف الإعدادات في المسار الافتراضي (بدون تمريره كـ Flag)
# سنقوم بحقن الإعدادات في ملف يسمى .moltbot.json أو moltbot.json في مجلد العمل
RUN echo '{"gateway": {"trustedProxies": ["0.0.0.0/0"], "token": "Medo1996"}}' > /app/moltbot.json

ENV HOST=0.0.0.0
ENV PORT=18789
ENV CLAWDBOT_STATE_DIR=/home/node/data
# إجبار البوت على رؤية المتغير من البيئة المحيطة كحل أخير بجانب الملف
ENV MOLTBOT_TRUSTED_PROXIES=0.0.0.0/0

# سطر التشغيل: بسيط جداً لتجنب "unknown option"
CMD ["sh", "-c", "socat TCP-LISTEN:18790,fork,bind=0.0.0.0 TCP:127.0.0.1:18789 & node dist/index.js gateway --port 18789 --allow-unconfigured --token Medo1996"]
