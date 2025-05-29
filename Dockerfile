FROM --platform=$BUILDPLATFORM node:18-bullseye-slim

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates \
    procps \
    libxss1 \
    libgconf-2-4 \
    libxrandr2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libcairo-gobject2 \
    libgtk-3-0 \
    libgdk-pixbuf2.0-0 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxtst6 \
    libxss1 \
    libx11-xcb1 \
    libnss3 \
    libnspr4 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxkbcommon0 \
    libatspi2.0-0 \
    libgtk-3-0 \
    curl \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        apt-get update && \
        apt-get install -y chromium && \
        rm -rf /var/lib/apt/lists/*; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        apt-get update && \
        apt-get install -y chromium && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        echo "Unsupported platform: $TARGETPLATFORM" && exit 1; \
    fi

WORKDIR /app

RUN groupadd -r appuser && useradd -r -g appuser -G audio,video appuser

COPY package*.json ./

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV PUPPETEER_ARGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage"

RUN npm ci --omit=dev && npm cache clean --force

COPY . .

RUN mkdir -p /app/.wwebjs_auth /app/logs && \
    chown -R appuser:appuser /app

COPY healthcheck.js ./
RUN chmod +x healthcheck.js

USER appuser

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node healthcheck.js || exit 1

EXPOSE 3000

ENV NODE_ENV=production

CMD ["node", "index.js"]