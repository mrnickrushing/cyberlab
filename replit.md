# CyberLab Mobile: Remote Cybersecurity Lab Controller

iOS app + backend API for managing a personal cybersecurity lab. The iPhone app connects securely to a private server where approved tools run inside Docker containers. Built for personal labs, owned networks, and authorized testing only.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — run the API server (port 5000)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- Required env: `DATABASE_URL`, `JWT_SECRET` — see `.env.example`

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- API: Express 5
- DB: PostgreSQL + Drizzle ORM
- Validation: Zod (`zod/v4`), `drizzle-zod`
- Auth: JWT (access 7d + refresh 30d), bcrypt, rate-limiter-flexible + Redis
- API codegen: Orval (from OpenAPI spec)
- Build: esbuild (CJS bundle)
- Logging: Pino

## Where things live

| Path | What it is |
|---|---|
| `lib/db/src/schema/` | Source-of-truth DB schema (Drizzle) |
| `lib/api-spec/openapi.yaml` | Source-of-truth API contract (OpenAPI 3.1) |
| `lib/api-zod/src/generated/` | Auto-generated Zod types (run codegen) |
| `lib/api-client-react/src/generated/` | Auto-generated React query hooks (run codegen) |
| `artifacts/api-server/src/` | Express server — routes, middleware, lib |
| `artifacts/mockup-sandbox/` | UI component sandbox (React) |

## Architecture decisions

- **OpenAPI first:** The spec in `api-spec/openapi.yaml` drives code generation for both the Zod validation layer and the React client hooks. Edit the spec, then run codegen — never edit generated files directly.
- **Docker workers:** Scanner tools (nmap, nuclei, nikto, etc.) run in isolated Docker containers. The API dispatches jobs to the worker queue; containers are ephemeral.
- **Authorization gate:** The `authorize-target` middleware enforces that a target's `authorizationStatus` is `"authorized"` before any scan job is accepted. This is a hard constraint, not a UI hint.
- **Audit everything:** The `logAudit` helper is called at every login, logout, scan request, and finding change. Audit logs are immutable (insert-only).
- **Lab-only mode:** RFC-1918 and localhost IP enforcement is planned at the IP-utils layer. Public IPs are blocked by default unless explicitly overridden per-target.

## Product

CyberLab Mobile covers: target management, port scanning (nmap/masscan), network mapping, DNS tools, web assessment (ZAP/Nikto/Nuclei), SSL/TLS analysis, OSINT (Shodan/VirusTotal/HIBP), vulnerability tracking with CVE/CVSS data, PDF report generation, an AI assistant for finding explanations and remediation, and lab notes with Markdown support.

## User preferences

- Lab-only mode is the default — no public target scanning without explicit authorization.
- The AI assistant must not generate exploit steps against real systems.
- All scans require an authorization checkbox in the UI before submission.

## Gotchas

- `JWT_SECRET` must be set before starting the API server — it throws on startup if missing.
- Run `pnpm --filter @workspace/api-spec run codegen` after any change to `openapi.yaml` or the generated types will be stale.
- `pnpm --filter @workspace/db run push` is for dev only — use migrations in production.
- The `artifacts/api-server` package is the runnable server; `lib/` packages are shared libraries consumed by it.

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
- Full feature spec and setup guide: `README.md`
- Environment variables template: `.env.example`
