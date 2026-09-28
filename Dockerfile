# zcode2api 运行镜像：Python 网关 + Node 验证码求解器（无浏览器，适合 NAS 长跑）
FROM python:3.12-slim

# ── 内嵌 Node 20（captcha_node 求解器运行时；happy-dom 为纯 JS 依赖，无需编译）──
COPY --from=node:20-slim /usr/local/bin/node /usr/local/bin/node
COPY --from=node:20-slim /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && node --version && npm --version

WORKDIR /app

# ── Python 依赖 ──
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# ── 验证码求解器依赖（happy-dom，预装进镜像）──
COPY captcha_node/package.json captcha_node/package-lock.json captcha_node/
RUN cd captcha_node && npm ci --omit=dev && npm cache clean --force

# ── 应用代码 ──
COPY . .
RUN chmod +x /app/add-account.sh

ENV ZCODE_PORT=3000 \
    ZCODE_HOST=0.0.0.0 \
    ZCODE_DATA_DIR=/data \
    ZCODE_NODE_PATH=node

VOLUME ["/data"]
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/meta' % os.environ.get('ZCODE_PORT','3000'), timeout=3)"

CMD ["python", "cli.py", "serve"]