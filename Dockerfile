FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG CLAWDBOT_DOCKER_APT_PACKAGES=""
RUN if [ -n "$CLAWDBOT_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $CLAWDBOT_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN CLAWDBOT_A2UI_SKIP_MISSING=1 pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV CLAWDBOT_PREFER_PNPM=1
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

# --- الجزء المعدل لحل مشكلة الصلاحيات ---
USER root

# إنشاء المجلدات المطلوبة مسبقاً وتغيير ملكيتها للمستخدم node
# ده بيضمن إن التطبيق يقدر يكتب جوه المجلدات حتى لو هي Volumes
RUN mkdir -p /home/node/data /home/node/workspace && \
    chown -R node:node /home/node/data /home/node/workspace && \
    chmod -R 755 /home/node/data /home/node/workspace

# العودة للمستخدم node للأمان
USER node

# ضبط المتغيرات لضمان عمل التطبيق على الـ Host الصحيح والمسارات الصحيحة
ENV MOLTBOT_HOST=0.0.0.0
ENV CLAWDBOT_STATE_DIR=/home/node/data
ENV CLAWDBOT_WORKSPACE_DIR=/home/node/workspace

# إضافة --host 0.0.0.0 و --token لضمان تجاوز الـ Bad Gateway وتأمين الدخول
CMD ["node", "dist/index.js", "gateway", "--port", "18789", "--host", "0.0.0.0", "--allow-unconfigured", "--token", "123456789"]
