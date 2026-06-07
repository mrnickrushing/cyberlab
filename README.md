# CyberLab Mobile: Remote Cybersecurity Lab Controller

A professional iOS app for managing a personal cybersecurity lab. The iPhone app never runs dangerous tools directly on-device — it connects securely to a private Kali Linux or Ubuntu server where approved tools run inside Docker containers.

> **CyberLab Mobile is built for personal cybersecurity labs, owned networks, and authorized security testing only. The project is intended for education, defensive assessment, asset inventory, vulnerability management, and reporting. Users are responsible for ensuring they have permission before scanning any system.**

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Security Model](#security-model)
- [Tool Coverage](#tool-coverage)
- [Database Schema](#database-schema)
- [Project Structure](#project-structure)
- [Setup Guide](#setup-guide)
- [API Documentation](#api-documentation)
- [Roadmap](#roadmap)
- [Legal & Ethical Use](#legal--ethical-use)

---

## Overview

CyberLab Mobile lets you manage targets, launch scans, view results, map networks, track vulnerabilities, generate reports, and document security work — all from an iPhone.

The app is a remote controller only. All scanning, enumeration, and analysis happens on your own private server inside isolated Docker containers. The iOS client communicates with the backend API over HTTPS using JWT authentication and Face ID unlock.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     iOS App (Swift)                     │
│   SwiftUI · SwiftData · LocalAuthentication (Face ID)   │
│   URLSession · PDFKit · Charts                          │
└────────────────────────┬────────────────────────────────┘
                         │ HTTPS + JWT
                         ▼
┌─────────────────────────────────────────────────────────┐
│               Backend API (Node.js / Express)            │
│   TypeScript · Drizzle ORM · Zod validation             │
│   JWT auth · Rate limiting · Audit logging              │
└──────────┬──────────────────────┬───────────────────────┘
           │                      │
           ▼                      ▼
┌─────────────────┐    ┌──────────────────────────────────┐
│   PostgreSQL    │    │        Docker Workers             │
│   (primary DB)  │    │  Nmap · Nuclei · Nikto · ZAP     │
│                 │    │  Amass · Subfinder · testssl.sh   │
└─────────────────┘    │  theHarvester · WhatWeb · whois  │
                       └──────────────────────────────────┘
```

**Server options:** Kali Linux VPS, Ubuntu server, or home lab machine.

---

## Features

### 1. Dashboard
- Security score summary
- Active scan status and progress
- Recent findings and critical alerts
- Saved targets and open port counts
- Vulnerability counts by severity
- Lab health status
- Quick-action shortcuts

### 2. Target Manager
- Add IP, domain, subnet, and web app targets
- Per-target notes, owner field, and authorization status
- Target tags, scan scope, and risk level
- Archive and delete targets
- Full target history

### 3. Authorization Controls
- Required authorization checkbox before any scan launches
- Scope notes and allowed IP range enforcement
- Default block on public targets
- Per-user rate limits
- Full scan and activity audit logs
- Legal warning screen on first launch
- Lab-only mode
- Exportable audit trail

### 4. Network Mapper
- Live host discovery on local subnet
- Device list with IP, MAC, hostname, and vendor
- Open port and service detection
- Network topology visualization
- Group devices by subnet, mark trusted vs. unknown
- Save and compare network maps over time
- **Tools:** nmap, arp-scan, ping, traceroute

### 5. Port Scanner
- Quick scan, full TCP, UDP, and custom port range
- Service and version detection
- Banner grabbing
- Scan timing profiles
- Live progress tracking
- Save and compare scan profiles
- Highlight newly opened or closed ports
- **Tools:** nmap, masscan (lab-only), netcat

### 6. DNS Tools
- Forward/reverse DNS lookup
- MX, TXT, NS, CNAME record queries
- Zone transfer testing
- Subdomain discovery
- Export DNS results
- **Tools:** dig, nslookup, Amass, Subfinder

### 7. Web Assessment
- HTTP header and security header analysis
- TLS/SSL configuration check
- Cookie security review
- Redirect chain viewer
- Technology stack detection
- Directory discovery (authorized lab targets only)
- Basic web vulnerability scan
- OWASP category tagging
- **Tools:** OWASP ZAP, Nikto, WhatWeb, Nuclei, Gobuster

### 8. SSL/TLS Analyzer
- Certificate viewer and expiration check
- Issuer and SAN list
- TLS version and cipher suite summary
- Weak configuration warnings
- Exportable certificate report
- **Tools:** OpenSSL, testssl.sh

### 9. Vulnerability Intelligence
- CVE search with CVSS scores and severity labels
- Affected software notes and remediation guidance
- Mark findings as fixed, open, accepted risk, or false positive
- Finding timeline and status history
- **Sources:** NVD, CISA KEV catalog, Exploit-DB (reference links only), vendor advisories

### 10. OSINT Tools
- WHOIS and ASN lookup
- IP geolocation
- Domain reputation
- Email breach lookup (approved APIs only)
- Shodan and VirusTotal integration
- Saved OSINT notes
- **APIs:** Shodan, VirusTotal, Have I Been Pwned, AbuseIPDB, IPinfo

### 11. Wireless Analyzer
- Connected WiFi SSID (where iOS permits)
- Local IP, gateway, and DNS server info
- Backend-based network discovery
- Save trusted networks
- Detect unknown devices on home lab network
- WiFi security checklist
- **Note:** Monitor mode, packet injection, and raw packet capture are not available on iOS and are intentionally excluded.

### 12. Reports
- PDF report generation with executive summary
- Technical findings, open ports table, vulnerability table
- Screenshots section, remediation recommendations
- Risk score and scan date metadata
- Export to Files app and share sheet
- Full report history

### 13. AI Assistant
- Explain scan findings in plain language
- Summarize vulnerabilities
- Suggest remediation steps
- Generate report summaries
- Create study notes and help write lab documentation
- **Safety rule:** The AI assistant will not generate exploit steps or attack instructions targeting real public systems.

### 14. Lab Notes
- Notes per target with evidence, screenshots, and Markdown support
- Tag and search notes
- Export notes

### 15. Scan History
- Filter scans by target, tool, severity, or date
- View raw and parsed output
- Re-run or compare any two scans
- Delete old scan records

### 16. Notifications
- Scan completed / failed
- Critical finding detected
- Certificate expiring soon
- New unknown device on network
- Scheduled scan completed

### 17. Settings
- API server URL and key management
- Face ID unlock toggle
- Theme and tool preferences
- Scan rate limit controls
- Default scan profile selection
- Export database
- Clear local cache
- Legal notice

---

## Tech Stack

### iOS
| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Data | SwiftData / Core Data |
| Charts | Swift Charts |
| Auth | LocalAuthentication (Face ID) |
| Networking | URLSession |
| Reports | PDFKit |
| Preview | WebKit |

### Backend
| Layer | Technology |
|---|---|
| Runtime | Node.js 24, TypeScript 5.9 |
| Framework | Express 5 |
| Database | PostgreSQL + Drizzle ORM |
| Validation | Zod v4, drizzle-zod |
| Auth | JWT (access + refresh tokens), bcrypt |
| Rate limiting | rate-limiter-flexible + Redis |
| Job queue | Redis + Celery/RQ workers |
| Logging | Pino |
| API spec | OpenAPI 3.1 + Orval codegen |
| Build | esbuild |
| Packages | pnpm workspaces |

### Scanner Containers (Docker)
- nmap
- masscan (private lab only)
- nuclei
- nikto
- OWASP ZAP
- Amass / Subfinder
- WhatWeb
- testssl.sh
- theHarvester
- dig / whois / arp-scan

---

## Security Model

| Control | Implementation |
|---|---|
| Transport | HTTPS only; no HTTP fallback |
| Authentication | JWT access tokens (7d) + refresh tokens (30d) |
| Mobile unlock | Face ID via LocalAuthentication |
| Authorization | Per-target authorization status required before scan launch |
| Public target protection | Lab-only mode blocks non-RFC-1918 targets by default |
| Rate limiting | Per-IP and per-user limits on auth and scan endpoints |
| Audit trail | Every scan request, login, and finding change is logged |
| Container isolation | Each scan tool runs in an isolated Docker container |
| Input validation | Zod schemas on all API inputs; no raw SQL |
| Secrets | Environment variables only; never committed |

---

## Tool Coverage (CEH-aligned)

### Reconnaissance
- WHOIS, DNS lookup, reverse DNS
- Subdomain discovery (Amass, Subfinder)
- Shodan, theHarvester
- IP geolocation, ASN lookup

### Scanning
- TCP/UDP port scanning (nmap, masscan — lab only)
- Host discovery (ping, arp-scan, traceroute)
- Service and version detection

### Enumeration
- SMB enumeration (lab machines)
- SNMP checks (lab machines)
- HTTP enumeration, DNS enumeration
- Service banner grabbing

### Vulnerability Analysis
- Nuclei, Nikto, OWASP ZAP
- testssl.sh for TLS
- NVD and CISA KEV database lookups

### Web Tools
- WhatWeb / Wappalyzer-style detection
- Gobuster (authorized lab targets only)
- HTTP header and cookie analyzer
- Redirect chain viewer

### Reporting
- Severity-rated findings (Critical / High / Medium / Low / Info)
- OWASP category tagging
- CVSS scores
- PDF export with remediation steps and scan evidence

---

## Database Schema

| Table | Purpose |
|---|---|
| `users` | Account credentials and profile |
| `targets` | IP, domain, subnet, and web app targets |
| `scan_profiles` | Saved tool + flag presets |
| `scan_jobs` | Scan execution records with status and progress |
| `scan_results` | Raw output and parsed JSON per scan |
| `findings` | Individual vulnerability records with CVE/CVSS data |
| `finding_events` | Status change history for each finding |
| `network_maps` | Saved network discovery snapshots |
| `network_hosts` | Discovered devices per network map |
| `notes` | Markdown notes and evidence per target |
| `audit_logs` | Full activity log for compliance and review |

---

## Project Structure

```
cyberlab/
├── artifacts/
│   ├── api-server/          # Express API server
│   │   └── src/
│   │       ├── app.ts
│   │       ├── routes/      # auth, health, ...
│   │       ├── middleware/  # authenticate, authorize-target
│   │       └── lib/         # auth, audit, rate-limiter, logger, ip-utils
│   └── mockup-sandbox/      # UI component sandbox (React)
├── lib/
│   ├── db/                  # Drizzle ORM schema and client
│   │   └── src/schema/      # users, targets, scan_jobs, findings, ...
│   ├── api-spec/            # OpenAPI 3.1 YAML source of truth
│   ├── api-zod/             # Generated Zod types from OpenAPI
│   └── api-client-react/    # Generated React query hooks from OpenAPI
└── scripts/                 # Workspace tooling
```

---

## Setup Guide

### Prerequisites

- Node.js 24+
- pnpm 9+
- PostgreSQL 15+
- Redis 7+
- Docker and Docker Compose
- (For scanning) Kali Linux or Ubuntu server

### 1. Clone and install

```bash
git clone https://github.com/mrnickrushing/cyberlab.git
cd cyberlab
pnpm install
```

### 2. Configure environment

```bash
cp .env.example .env
```

Edit `.env`:

```env
DATABASE_URL=postgresql://user:password@localhost:5432/cyberlab
REDIS_URL=redis://localhost:6379
JWT_SECRET=change-this-to-a-long-random-secret
NODE_ENV=development
PORT=5000
```

### 3. Set up the database

```bash
# Push the Drizzle schema to PostgreSQL
pnpm --filter @workspace/db run push
```

### 4. Start the API server

```bash
pnpm --filter @workspace/api-server run dev
```

The server starts on `http://localhost:5000`. Health check: `GET /api/healthz`

### 5. Docker scanner workers

```bash
# Coming in Phase 2 — see docker/compose.yml (planned)
docker compose up -d
```

### 6. iOS app

Open `ios/CyberLabMobile.xcodeproj` in Xcode 15+, set your development team, and run on a physical device (Face ID requires real hardware).

Set the API server URL in **Settings → API Server URL** once the app is installed.

### 7. Run all checks

```bash
pnpm run typecheck    # TypeScript check across all packages
pnpm run build        # Full build
```

### Regenerate API client (after editing openapi.yaml)

```bash
pnpm --filter @workspace/api-spec run codegen
```

---

## API Documentation

The OpenAPI 3.1 spec lives at `lib/api-spec/openapi.yaml`. View it with any OpenAPI-compatible viewer (Swagger UI, Scalar, Redocly).

### Current endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/api/healthz` | Server health check |
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Login, receive JWT |
| POST | `/api/auth/refresh` | Refresh access token |
| GET | `/api/auth/me` | Current user profile |
| POST | `/api/auth/logout` | Logout (audit logged) |

More endpoints are added each phase. The OpenAPI spec is the source of truth — client hooks and Zod schemas are auto-generated from it.

---

## Roadmap

### Phase 1 — Foundation ✅
- [x] Monorepo structure (pnpm workspaces)
- [x] PostgreSQL schema (users, targets, scan jobs, findings, notes, audit logs)
- [x] JWT auth with bcrypt, refresh tokens, rate limiting
- [x] Audit logging middleware
- [x] OpenAPI spec + codegen pipeline
- [x] iOS SwiftUI app — Face ID unlock, target manager, scan history, findings, notes, dashboard
- [x] API live on Railway with PostgreSQL + 7 scan profiles seeded

### Phase 2 — First Real Scanner ✅
- [x] Python Celery worker deployed on Railway as isolated service
- [x] All scan tools coded: nmap, masscan, arp-scan, nikto, nuclei, WhatWeb, testssl, gobuster, amass, subfinder, dig/DNS, whois, Shodan, VirusTotal
- [x] XML nmap parsing → structured host/port data
- [x] Auto-findings engine — generates severity-rated findings after every scan
- [x] Redis job queue pipeline (api-server → Redis → worker) verified end-to-end
- [x] iOS scan profile screen, live polling, scan history UI, scan detail with raw output

### Phase 3 — Network Mapper ✅
- [x] `POST /networks` — create named subnet maps; `GET`, `DELETE` routes
- [x] `POST /networks/:id/discover` — auto-creates subnet target + enqueues arp-scan
- [x] Worker auto-populates `network_hosts` after arp-scan completes (with reverse DNS)
- [x] `PATCH /networks/:id/hosts/:hostId` — toggle trusted / mark gateway
- [x] iOS **Networks** tab — list of saved maps with subnet, host count, last-scanned time
- [x] iOS **Device list** — IP, MAC, hostname, vendor, trusted/gateway badges, context menu
- [x] iOS **Topology view** — SwiftUI Canvas hub-and-spoke; gateway centred, hosts in ring, colour-coded by trust
- [x] iOS **Diff view** — select any two maps and compare: NEW / GONE / CHANGED / SAME with per-host delta

### Phase 4 — Web & Vulnerability Tools ✅
- [x] WhatWeb technology stack detection — tech grid with name, version, detail chips
- [x] Nikto web vulnerability scan — collapsible finding rows with severity badges
- [x] Nuclei template-based scanner — matched-at URL, tags, expandable descriptions
- [x] TLS audit via testssl.sh — cipher/protocol issues with severity classification
- [x] OpenSSL cert viewer — subject, issuer, expiry, protocol, cipher, verify status
- [x] Gobuster directory discovery — path + HTTP status code list
- [x] NVD CVE enrichment — after nikto/nuclei/shodan scans, worker fetches CVSS score + NVD description and updates findings automatically
- [x] Rich `ScanDetailView` — dispatches to tool-specific result card (nmap hosts, tech stack, finding lists, TLS cert, directories, DNS, subdomains)
- [x] `WebAssessmentView` — per-target "Web" tab with 6 tool cards, inline progress + results, one-tap launch

### Phase 5 — Reports ✅
- [x] `GET /reports` — list all targets with risk score, severity breakdown, scan count
- [x] `GET /reports/:targetId` — full report JSON: target, risk score, open findings sorted by severity, scan history, deduplicated remediation steps
- [x] Risk score algorithm: starts at 100, deducts Critical −25 · High −15 · Medium −10 · Low −5 · Info −1 per open finding, clamped 0–100
- [x] iOS **Reports tab** — target list with animated risk gauge rings, severity chip breakdown, risk label badge
- [x] iOS **ReportDetailView** — executive summary grid, animated risk score dial, findings list (CVE + CVSS inline), remediation steps, scan history
- [x] iOS **PDF export** — full report rendered via `UIGraphicsPDFRenderer` with multi-page pagination, target header, risk gauge, finding rows with severity dots, remediation section, legal footer
- [x] Share sheet — native iOS share sheet for AirDrop, Files, Mail, etc.

### Phase 6 — OSINT & APIs ✅
- [x] **WHOIS** — domain registrar, org, country, creation/expiry, name servers
- [x] **Shodan** — exposed ports, banners, CVEs, ASN, org, geolocation, OS; findings auto-created per CVE
- [x] **VirusTotal** — malicious/suspicious/harmless engine counts, reputation score, findings for flagged targets
- [x] **AbuseIPDB** — abuse confidence score, TOR exit node detection, report count, ISP, usage type; findings at medium/high threshold
- [x] **IPinfo** — IP geolocation (lat/lon), ASN/org, city/region/country, hostname, timezone (no key required)
- [x] **Have I Been Pwned** — domain breach history, breach names list, breach count; findings for breached domains
- [x] Auto-findings for AbuseIPDB (≥25% → medium, ≥75% → high, TOR → medium) and HIBP (≥1 breach → medium/high)
- [x] iOS **OSINTView** — per-target OSINT tab with 6 tool cards (WHOIS, Shodan, VirusTotal, AbuseIPDB, IPinfo, HIBP), one-tap launch, inline result rendering with tool-specific layouts
- [x] iOS **OSINT tab** added as 5th tab in TargetDetailView alongside Scans, Findings, Notes, Web

### Phase 7 — AI Assistant ✅
- [x] `POST /ai/chat` — context-aware AI endpoint using Anthropic `claude-sonnet-4-6`; accepts mode, message, conversation history (up to 20 turns), and structured context (finding or report data); returns reply + token counts
- [x] `GET /ai/status` — reports whether `ANTHROPIC_API_KEY` is configured on the server
- [x] **5 AI modes**: General (free Q&A), Explain Finding, Summarize Report, Remediation Advisor, Lab Study Helper — each with its own system prompt and suggested starter questions
- [x] **Safety guardrails** baked into every system prompt: authorized lab use only, refuses to assist unauthorized scanning/exploitation, always recommends written authorization first
- [x] iOS **AIAssistantView** — full chat UI with: animated 3-dot typing indicator, per-corner rounded bubbles, mode pill selector, context banner showing injected finding/report data, quick-start suggestion chips, clear history button, unconfigured server warning banner
- [x] **"Ask AI" deep-links**: finding detail view → Explain mode with full CVE/CVSS/description context pre-loaded; report detail view → Summarize mode with risk score, severity breakdown, and top findings pre-loaded
- [x] **AI tab** added to main tab bar (8 tabs total: Dashboard, Targets, Scans, Networks, Findings, Reports, AI, Settings)

---

## Legal & Ethical Use

CyberLab Mobile is built for **personal cybersecurity labs, owned networks, and authorized security testing only**.

- Always obtain written authorization before scanning any system you do not own.
- Never use this tool to scan public infrastructure, third-party systems, or networks without explicit permission.
- Unauthorized scanning may violate the Computer Fraud and Abuse Act (CFAA), the UK Computer Misuse Act, and equivalent laws in your jurisdiction.
- The authorization checkbox and audit log exist to help you stay compliant — use them honestly.
- The AI assistant will not generate exploit steps or attack instructions against real systems.

**The developer assumes no liability for misuse. You are solely responsible for your actions.**
