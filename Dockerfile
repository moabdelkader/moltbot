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

# --- إصلاح الصلاحيات والبيئة ---
USER root

# إعداد المجلدات وضمان ملكية يوزر node لها لحل خطأ EACCES
RUN mkdir -p /home/node/data /home/node/workspace && \
    chown -R node:node /home/node/data /home/node/workspace && \
    chmod -R 755 /home/node/data /home/node/workspace

USER node

# تعريف المتغيرات كـ ENV بدلاً من CLI Flags لتجنب خطأ "unknown option"
ENV HOST=0.0.0.0
ENV MOLTBOT_HOST=0.0.0.0
ENV CLAWDBOT_STATE_DIR=/home/node/data
ENV CLAWDBOT_WORKSPACE_DIR=/home/node/workspace

# تم حذف --host من هنا ليعمل التطبيق بدون أخطاء، وسيعتمد على ENV HOST أعلاه
CMD ["node", "dist/index.js", "gateway", "--port", "18789", "--address", "0.0.0.0", "--allow-unconfigured", "--token", "123456789"]
