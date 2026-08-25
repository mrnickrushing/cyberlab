FROM node:22-slim

WORKDIR /app

RUN npm install -g pnpm@10

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY lib/db/package.json lib/db/
COPY lib/api-zod/package.json lib/api-zod/
COPY lib/api-client-react/package.json lib/api-client-react/
COPY lib/api-spec/package.json lib/api-spec/
COPY artifacts/api-server/package.json artifacts/api-server/

RUN pnpm install --frozen-lockfile

COPY lib/ lib/
COPY artifacts/api-server/ artifacts/api-server/
COPY tsconfig.base.json tsconfig.json ./

RUN pnpm --filter @workspace/api-server run build

ENV NODE_ENV=production
EXPOSE 8080

# Run as an unprivileged user. HOME stays writable so pnpm can keep its
# state when the start command runs the schema push.
RUN groupadd --system app \
    && useradd --system --gid app --home-dir /app --shell /usr/sbin/nologin app \
    && chown -R app:app /app
ENV HOME=/app
USER app

CMD ["sh", "-c", "pnpm --filter @workspace/db run push --force && node --enable-source-maps artifacts/api-server/dist/index.mjs"]
