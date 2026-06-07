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

CMD ["node", "--enable-source-maps", "artifacts/api-server/dist/index.mjs"]
