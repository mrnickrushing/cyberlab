# CyberLab

A personal mobile cybersecurity lab controller. The iOS app connects to this backend, which runs security tools (Nmap, DNS, SSL, web scanners) inside Docker containers on a private server. Built for personal labs, home networks, and authorized testing only.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — run the API server (port 8080)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- `docker-compose up` — start Redis + scanner worker (requires Docker)
- Required env: `DATABASE_URL`, `JWT_SECRET`, `REDIS_URL`, `LAB_ONLY_MODE`

## Stack

- pnpm workspaces, Node.js 22, TypeScript 5.9
- API: Express 5 (artifacts/api-server)
- DB: PostgreSQL + Drizzle ORM (lib/db)
- Validation: Zod, drizzle-zod
- Auth: JWT (jsonwebtoken + bcryptjs)
- Rate limiting: rate-limiter-flexible (in-memory)
- API codegen: Orval (OpenAPI → Zod + React Query)
- Build: esbuild (ESM bundle)
- Workers: Python + Celery + Redis (worker/)
- Deployment: Railway (railway.json + nixpacks.toml)
- GitHub: mrnickrushing/cyberlab — branch: feature/backend-foundation

## Where things live

- `lib/api-spec/openapi.yaml` — source of truth for all API contracts
- `lib/db/src/schema/` — Drizzle table definitions (one file per domain)
- `artifacts/api-server/src/routes/` — Express route handlers
- `artifacts/api-server/src/middleware/` — auth + authorization middleware
- `artifacts/api-server/src/lib/` — auth utils, audit logger, rate limiter, IP utils
- `worker/worker.py` — Celery scanner worker (dispatches Nmap, arp-scan, DNS)
- `docker-compose.yml` — Redis + worker for local dev
- `railway.json` + `nixpacks.toml` — Railway deployment config

## Database schema

Tables: `users`, `targets`, `scan_jobs`, `scan_results`, `scan_profiles`, `findings`, `finding_events`, `audit_logs`, `network_maps`, `network_hosts`, `notes`

## API surface (Phase 1)

- `POST /api/auth/register` — create account
- `POST /api/auth/login` — get JWT + refresh token
- `POST /api/auth/refresh` — refresh access token
- `GET  /api/auth/me` — current user (auth required)
- `POST /api/auth/logout`
- `GET/POST /api/targets` — list / create targets
- `GET/PATCH/DELETE /api/targets/:id`
- `POST /api/targets/:id/archive`
- `GET/POST /api/scans` — list / create scan jobs
- `GET/DELETE /api/scans/:id`
- `GET /api/scans/:id/results`
- `GET/POST /api/scan-profiles`
- `DELETE /api/scan-profiles/:id`
- `GET/POST /api/findings`
- `GET/PATCH/DELETE /api/findings/:id`
- `GET /api/findings/:id/timeline`
- `GET/POST /api/notes`
- `GET/PATCH/DELETE /api/notes/:id`
- `GET /api/audit`
- `GET /api/dashboard`
- `GET /api/healthz`

## Architecture decisions

- **Lab-only mode** (`LAB_ONLY_MODE=true` env): blocks scan jobs against public IPs. Enforced server-side in authorization middleware.
- **Authorization gate**: targets must be marked `authorized` before any scan job is accepted — prevents accidental scans.
- **Worker separation**: all tool execution (Nmap, arp-scan, etc.) runs in a separate Python/Celery process inside Docker, never in the Node.js server process.
- **esbuild externals**: `zod` is marked external in build.mjs since it uses workspace catalog resolution that esbuild can't trace at bundle time.
- **Audit trail**: every scan request, target mutation, and login is written to `audit_logs` for exportable compliance records.

## Railway deployment

1. Connect `mrnickrushing/cyberlab` repo to Railway
2. Set env vars: `DATABASE_URL`, `JWT_SECRET`, `REDIS_URL`, `LAB_ONLY_MODE`
3. Railway auto-detects `nixpacks.toml` → builds + starts the API server
4. For the worker: add a second Railway service pointing to `worker/` with the same `DATABASE_URL` and `REDIS_URL`

## Product

CyberLab lets security practitioners manage targets, launch authorized scans (Nmap, DNS, SSL, web tools), track findings with CVE/CVSS data, generate PDF reports, and document lab work — all from an iOS app connected to their private backend.

## User preferences

- GitHub repo: mrnickrushing/cyberlab.git
- Backend deployment: Railway
- Branch convention: feature/<phase-name>

## Gotchas

- `zod` must stay in the `external` list in `artifacts/api-server/build.mjs` — removing it breaks the esbuild bundle
- `git config.lock` can accumulate if multiple git processes run simultaneously — use `pnpm --filter @workspace/db run push-force` (not plain push) for schema changes
- Worker container needs `--privileged` or `cap_add: NET_RAW` for Nmap SYN scans (`-sS`)
- `drizzle-kit push --force` is safe for dev; use migrations for production schema changes
