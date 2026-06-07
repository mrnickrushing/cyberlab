"""
CyberLab Scanner Worker
Picks scan jobs from Redis queue, runs tools inside this container,
writes results + auto-generated findings back to DB.
"""
import os
import json
import logging
import subprocess
import re
from datetime import datetime, timezone
from celery import Celery
import psycopg2
from psycopg2.extras import Json

import threading
import http.server

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
DATABASE_URL = os.environ.get("DATABASE_URL", "")


def _start_health_server():
    """Minimal HTTP server so Railway's healthcheck passes."""
    port = int(os.environ.get("PORT", 8080))

    class _Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b'{"status":"ok","service":"cyberlab-worker"}')

        def log_message(self, *args):
            pass  # silence access logs

    server = http.server.HTTPServer(("0.0.0.0", port), _Handler)
    logger.info(f"Health server listening on :{port}")
    server.serve_forever()


threading.Thread(target=_start_health_server, daemon=True).start()

SHODAN_API_KEY = os.environ.get("SHODAN_API_KEY", "")
VIRUSTOTAL_API_KEY = os.environ.get("VIRUSTOTAL_API_KEY", "")
ABUSEIPDB_API_KEY = os.environ.get("ABUSEIPDB_API_KEY", "")
IPINFO_TOKEN = os.environ.get("IPINFO_TOKEN", "")
HIBP_API_KEY = os.environ.get("HIBP_API_KEY", "")

app = Celery("cyberlab", broker=REDIS_URL, backend=REDIS_URL)

app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
)


import urllib.request as _urllib_request

def get_db():
    return psycopg2.connect(DATABASE_URL)


_CVE_RE = re.compile(r"CVE-\d{4}-\d{4,7}", re.IGNORECASE)


def enrich_findings_with_nvd(job_id: str):
    """Fetch CVSS score + description from NVD for any CVE-bearing findings."""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, title, description FROM findings WHERE scan_job_id = %s AND cve_id IS NULL",
                (job_id,),
            )
            rows = cur.fetchall()
        for finding_id, title, desc in rows:
            match = _CVE_RE.search(title or "") or _CVE_RE.search(desc or "")
            if not match:
                continue
            cve_id = match.group(0).upper()
            try:
                url = f"https://services.nvd.nist.gov/rest/json/cves/2.0?cveId={cve_id}"
                req = _urllib_request.Request(url, headers={"User-Agent": "CyberLab/1.0"})
                with _urllib_request.urlopen(req, timeout=10) as resp:
                    data = json.loads(resp.read())
                vuln = data.get("vulnerabilities", [{}])[0].get("cve", {})
                metrics = vuln.get("metrics", {})
                cvss_score = None
                for key in ("cvssMetricV31", "cvssMetricV30", "cvssMetricV2"):
                    items = metrics.get(key, [])
                    if items:
                        cvss_score = items[0].get("cvssData", {}).get("baseScore")
                        break
                nvd_desc = (vuln.get("descriptions") or [{}])[0].get("value", "")
                with conn.cursor() as cur:
                    cur.execute(
                        """UPDATE findings SET cve_id = %s, cvss_score = %s,
                           description = CASE WHEN %s <> '' THEN %s ELSE description END,
                           updated_at = %s WHERE id = %s""",
                        (cve_id, cvss_score, nvd_desc, nvd_desc, datetime.now(timezone.utc), finding_id),
                    )
                conn.commit()
                logger.info(f"NVD enriched {cve_id} → CVSS {cvss_score}")
            except Exception as exc:
                logger.debug(f"NVD lookup failed for {cve_id}: {exc}")
    except Exception as exc:
        logger.warning(f"NVD enrichment skipped: {exc}")
    finally:
        conn.close()


def update_job_status(job_id: str, status: str, error_message: str = None, worker_job_id: str = None):
    conn = get_db()
    try:
        with conn.cursor() as cur:
            fields = ["status = %s", "updated_at = %s"]
            values = [status, datetime.now(timezone.utc)]
            if status == "running":
                fields.append("started_at = %s")
                values.append(datetime.now(timezone.utc))
            if status in ("completed", "failed", "cancelled"):
                fields.append("completed_at = %s")
                values.append(datetime.now(timezone.utc))
            if error_message is not None:
                fields.append("error_message = %s")
                values.append(error_message)
            if worker_job_id is not None:
                fields.append("worker_job_id = %s")
                values.append(worker_job_id)
            values.append(job_id)
            cur.execute(
                f"UPDATE scan_jobs SET {', '.join(fields)} WHERE id = %s",
                values,
            )
        conn.commit()
    finally:
        conn.close()


def save_result(job_id: str, raw_output: str, parsed_data: dict):
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO scan_results (id, scan_job_id, raw_output, parsed_data, created_at)
                VALUES (gen_random_uuid(), %s, %s, %s, %s)
                ON CONFLICT DO NOTHING
                """,
                (job_id, raw_output, Json(parsed_data), datetime.now(timezone.utc)),
            )
        conn.commit()
    finally:
        conn.close()


def get_job(job_id: str) -> dict:
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT sj.id, sj.tool, sj.flags, sj.target_id,
                       t.address, t.type, sj.user_id, sj.meta
                FROM scan_jobs sj
                JOIN targets t ON t.id = sj.target_id
                WHERE sj.id = %s
                """,
                (job_id,),
            )
            row = cur.fetchone()
            if not row:
                return None
            return {
                "id": row[0],
                "tool": row[1],
                "flags": row[2],
                "target_id": row[3],
                "address": row[4],
                "target_type": row[5],
                "user_id": row[6],
                "meta": row[7] or {},
            }
    finally:
        conn.close()


def populate_network_hosts(network_map_id: str, hosts: list):
    """Refresh network_hosts for a map after arp-scan completes."""
    if not hosts:
        return
    conn = get_db()
    try:
        with conn.cursor() as cur:
            # Clear previous snapshot for this map
            cur.execute("DELETE FROM network_hosts WHERE network_map_id = %s", (network_map_id,))
            now = datetime.now(timezone.utc)
            for host in hosts:
                cur.execute(
                    """
                    INSERT INTO network_hosts
                        (id, network_map_id, ip_address, mac_address, hostname, vendor,
                         open_ports, is_trusted, is_gateway, first_seen, last_seen)
                    VALUES (gen_random_uuid(), %s, %s, %s, %s, %s, %s, false, false, %s, %s)
                    """,
                    (
                        network_map_id,
                        host.get("ip"),
                        host.get("mac"),
                        host.get("hostname"),
                        host.get("vendor"),
                        Json([]),
                        now,
                        now,
                    ),
                )
            cur.execute(
                "UPDATE network_maps SET scanned_at = %s WHERE id = %s",
                (now, network_map_id),
            )
        conn.commit()
        logger.info(f"Populated {len(hosts)} hosts into network map {network_map_id}")
    except Exception as exc:
        logger.warning(f"Failed to populate network hosts: {exc}")
    finally:
        conn.close()


# ─── Auto-Findings ────────────────────────────────────────────────────────────

# Port → (title, severity, description, remediation)
INTERESTING_PORTS = {
    21:   ("FTP Service Exposed", "medium",
           "FTP transmits credentials and data in plaintext.",
           "Disable FTP and use SFTP or SCP instead. If FTP is required, enforce TLS (FTPS)."),
    22:   ("SSH Service Detected", "info",
           "SSH service is open. Verify it is intentional and hardened.",
           "Disable password authentication, use key-based auth, restrict to known IPs."),
    23:   ("Telnet Service Exposed", "high",
           "Telnet transmits all data including credentials in plaintext.",
           "Disable Telnet immediately and replace with SSH."),
    25:   ("SMTP Service Exposed", "low",
           "SMTP service is open. May allow relay abuse if misconfigured.",
           "Restrict SMTP relay to authenticated clients only."),
    53:   ("DNS Service Exposed", "info",
           "DNS service is open. Verify zone transfer is disabled.",
           "Disable recursive DNS for external clients. Restrict AXFR/zone transfers."),
    80:   ("HTTP Service (Unencrypted)", "low",
           "Web server running on plain HTTP without TLS.",
           "Redirect all HTTP traffic to HTTPS. Obtain and install a TLS certificate."),
    110:  ("POP3 Service Exposed", "medium",
           "POP3 may transmit credentials in plaintext.",
           "Disable plain POP3 and use POP3S (port 995) with TLS."),
    135:  ("MSRPC Exposed", "medium",
           "Microsoft RPC endpoint mapper is exposed externally.",
           "Block port 135 at the firewall for external connections."),
    139:  ("NetBIOS Session Service Exposed", "medium",
           "NetBIOS is exposed, potentially leaking host information.",
           "Disable NetBIOS over TCP/IP if not required. Block at firewall."),
    143:  ("IMAP Service Exposed", "low",
           "IMAP may allow plaintext authentication.",
           "Enforce IMAPS (port 993) with TLS only."),
    161:  ("SNMP Exposed", "high",
           "SNMP v1/v2 uses community strings (essentially plaintext passwords).",
           "Upgrade to SNMPv3 with authentication and encryption. Restrict to management IPs."),
    389:  ("LDAP Exposed", "medium",
           "LDAP service is exposed. May leak directory information.",
           "Use LDAPS (port 636) or StartTLS. Restrict to internal network."),
    443:  ("HTTPS Service Detected", "info",
           "HTTPS/TLS service is running.",
           "Verify TLS configuration (certificate validity, cipher suites, protocol version)."),
    445:  ("SMB/CIFS Exposed", "high",
           "SMB service is exposed. High risk of exploitation (EternalBlue, ransomware).",
           "Block port 445 at the firewall for external access. Apply all Windows patches."),
    1433: ("MSSQL Database Exposed", "high",
           "Microsoft SQL Server is directly exposed.",
           "Move behind firewall. Restrict to application servers only."),
    1521: ("Oracle DB Exposed", "high",
           "Oracle database listener is directly exposed.",
           "Move behind firewall. Restrict to application servers only."),
    2375: ("Docker API Exposed (Unauthenticated)", "critical",
           "Docker daemon is exposed without TLS authentication — full host compromise risk.",
           "Enable TLS authentication on Docker socket or restrict to localhost only."),
    2376: ("Docker API Exposed (TLS)", "medium",
           "Docker TLS API is exposed. Verify certificate authentication is enforced.",
           "Ensure mutual TLS is enforced on the Docker API."),
    3306: ("MySQL Database Exposed", "high",
           "MySQL is directly accessible from the network.",
           "Move behind firewall. Bind to localhost or restrict to application server IPs."),
    3389: ("RDP (Remote Desktop) Exposed", "high",
           "RDP is exposed and is a common attack target (BlueKeep, credential brute-force).",
           "Restrict RDP to VPN/jump host. Enable Network Level Authentication. Apply patches."),
    5432: ("PostgreSQL Database Exposed", "high",
           "PostgreSQL is directly accessible from the network.",
           "Move behind firewall. Bind to localhost or restrict to application server IPs."),
    5900: ("VNC Service Exposed", "high",
           "VNC remote desktop is exposed, often with weak authentication.",
           "Restrict to VPN. Use strong passwords or require SSH tunneling for VNC."),
    6379: ("Redis Exposed (Unauthenticated)", "critical",
           "Redis is accessible without authentication — data theft and RCE risk.",
           "Bind Redis to localhost. Enable requirepass. Never expose to the internet."),
    8080: ("HTTP Alternate Port Open", "info",
           "HTTP service running on alternate port 8080.",
           "Verify this is intentional. Ensure it redirects to HTTPS if a web app."),
    8443: ("HTTPS Alternate Port Open", "info",
           "HTTPS service running on alternate port 8443.",
           "Verify TLS configuration is correct."),
    9200: ("Elasticsearch Exposed", "critical",
           "Elasticsearch API is publicly accessible — all data is readable without auth.",
           "Enable X-Pack security. Restrict to internal network. Never expose to internet."),
    27017: ("MongoDB Exposed", "critical",
            "MongoDB is directly accessible without authentication.",
            "Enable MongoDB authentication. Bind to localhost. Move behind firewall."),
}


def create_findings_from_scan(job_id: str, target_id: str, user_id: str, tool: str, parsed_data: dict):
    """Auto-create findings based on scan results."""
    findings = []

    if tool == "nmap":
        findings = _findings_from_nmap(parsed_data)
    elif tool == "arp-scan":
        findings = _findings_from_arp_scan(parsed_data)
    elif tool == "nuclei":
        findings = _findings_from_nuclei(parsed_data)
    elif tool == "nikto":
        findings = _findings_from_nikto(parsed_data)
    elif tool == "shodan":
        findings = _findings_from_shodan(parsed_data)
    elif tool == "virustotal":
        findings = _findings_from_virustotal(parsed_data)
    elif tool == "abuseipdb":
        findings = _findings_from_abuseipdb(parsed_data)
    elif tool == "hibp":
        findings = _findings_from_hibp(parsed_data)
    elif tool == "testssl":
        findings = _findings_from_testssl(parsed_data)

    if not findings:
        return

    conn = get_db()
    try:
        with conn.cursor() as cur:
            for f in findings:
                cur.execute(
                    """
                    INSERT INTO findings (
                        id, user_id, target_id, scan_job_id,
                        title, severity, status, description, remediation,
                        created_at, updated_at
                    ) VALUES (
                        gen_random_uuid(), %s, %s, %s,
                        %s, %s, 'open', %s, %s,
                        %s, %s
                    )
                    """,
                    (
                        user_id, target_id, job_id,
                        f["title"], f["severity"], f.get("description"), f.get("remediation"),
                        datetime.now(timezone.utc), datetime.now(timezone.utc),
                    ),
                )
        conn.commit()
        logger.info(f"Created {len(findings)} findings for job {job_id}")
    except Exception as e:
        logger.warning(f"Failed to create findings for job {job_id}: {e}")
    finally:
        conn.close()


def _findings_from_nmap(parsed_data: dict) -> list:
    findings = []
    hosts = parsed_data.get("hosts", [])
    for host in hosts:
        if host.get("status") != "up":
            continue
        for port_info in host.get("ports", []):
            if port_info.get("state") != "open":
                continue
            port_num = port_info.get("port")
            service = port_info.get("service") or ""
            product = port_info.get("product") or ""
            version = port_info.get("version") or ""

            if port_num in INTERESTING_PORTS:
                title, severity, description, remediation = INTERESTING_PORTS[port_num]
                detail_parts = []
                if product:
                    detail_parts.append(f"Product: {product}")
                if version:
                    detail_parts.append(f"Version: {version}")
                detail = f" ({', '.join(detail_parts)})" if detail_parts else ""
                findings.append({
                    "title": f"{title} — port {port_num}/{port_info.get('protocol','tcp')}{detail}",
                    "severity": severity,
                    "description": description,
                    "remediation": remediation,
                })
            elif service and service not in ("unknown", "tcpwrapped"):
                # Interesting service on non-standard port
                findings.append({
                    "title": f"Open port {port_num}/{port_info.get('protocol','tcp')} — {service}",
                    "severity": "info",
                    "description": f"Service '{service}' detected on port {port_num}. {product} {version}".strip(),
                    "remediation": "Verify this service is required and apply appropriate access controls.",
                })
    return findings


def _findings_from_arp_scan(parsed_data: dict) -> list:
    hosts = parsed_data.get("hosts", [])
    if not hosts:
        return []
    return [{
        "title": f"Network host discovered via ARP — {h['ip']}",
        "severity": "info",
        "description": f"Host {h['ip']} (MAC: {h.get('mac','unknown')}, Vendor: {h.get('vendor','unknown')}, Hostname: {h.get('hostname','unknown')}) is live on the network.",
        "remediation": "Verify this is an authorised device on the network.",
    } for h in hosts]


def _findings_from_nuclei(parsed_data: dict) -> list:
    findings = []
    severity_map = {"critical": "critical", "high": "high", "medium": "medium", "low": "low", "info": "info"}
    for f in parsed_data.get("findings", []):
        findings.append({
            "title": f.get("name") or f.get("template") or "Nuclei Finding",
            "severity": severity_map.get(f.get("severity", "").lower(), "info"),
            "description": f.get("description") or f"Nuclei template {f.get('template')} matched at {f.get('matched_at')}",
            "remediation": "Refer to the CVE or template documentation for remediation steps.",
        })
    return findings


def _findings_from_nikto(parsed_data: dict) -> list:
    findings = []
    for item in parsed_data.get("findings", []):
        if isinstance(item, str):
            findings.append({
                "title": item[:120] if len(item) > 120 else item,
                "severity": "medium",
                "description": item,
                "remediation": "Review web server configuration and apply appropriate hardening.",
            })
        elif isinstance(item, dict):
            findings.append({
                "title": item.get("msg") or item.get("id") or "Nikto Finding",
                "severity": "medium",
                "description": str(item),
                "remediation": "Review web server configuration and apply appropriate hardening.",
            })
    return findings


def _findings_from_shodan(parsed_data: dict) -> list:
    findings = []
    for vuln in parsed_data.get("vulns", []):
        findings.append({
            "title": f"Shodan CVE: {vuln}",
            "severity": "high",
            "description": f"Shodan detected vulnerability {vuln} on this host.",
            "remediation": f"Apply patches for {vuln}. Check NVD for details.",
        })
    ports = parsed_data.get("ports", [])
    for port in ports:
        if port in INTERESTING_PORTS:
            title, severity, description, remediation = INTERESTING_PORTS[port]
            findings.append({
                "title": f"{title} — port {port} (Shodan)",
                "severity": severity,
                "description": description,
                "remediation": remediation,
            })
    return findings


def _findings_from_virustotal(parsed_data: dict) -> list:
    malicious = parsed_data.get("malicious", 0)
    suspicious = parsed_data.get("suspicious", 0)
    if malicious > 3:
        return [{
            "title": "Malicious IP/Domain — VirusTotal",
            "severity": "critical",
            "description": f"VirusTotal reports {malicious} engines flagged this target as malicious.",
            "remediation": "Block this IP/domain immediately. Investigate any connections to it in logs.",
        }]
    elif malicious > 0 or suspicious > 3:
        return [{
            "title": "Suspicious IP/Domain — VirusTotal",
            "severity": "high",
            "description": f"VirusTotal reports {malicious} malicious and {suspicious} suspicious detections.",
            "remediation": "Investigate further. Consider blocking if reputation cannot be established.",
        }]
    return []


def _findings_from_testssl(parsed_data: dict) -> list:
    findings = []
    severity_map = {"CRITICAL": "critical", "HIGH": "high", "MEDIUM": "medium", "LOW": "low", "WARN": "low"}
    for item in parsed_data.get("findings", []):
        sev = severity_map.get(item.get("severity", "").upper(), "info")
        findings.append({
            "title": f"TLS Issue: {item.get('id', 'unknown')}",
            "severity": sev,
            "description": item.get("finding", "TLS misconfiguration detected."),
            "remediation": "Update TLS configuration to use modern cipher suites and protocol versions.",
        })
    return findings


# ─── Main Task ────────────────────────────────────────────────────────────────

@app.task(bind=True, name="run_scan", max_retries=2)
def run_scan(self, job_id: str):
    logger.info(f"Starting scan job {job_id}")
    update_job_status(job_id, "running", worker_job_id=self.request.id)

    job = get_job(job_id)
    if not job:
        logger.error(f"Job {job_id} not found in DB")
        update_job_status(job_id, "failed", error_message="Job not found")
        return

    tool = job["tool"]
    address = job["address"]
    flags = job["flags"] or ""

    try:
        raw_output, parsed_data = dispatch_tool(tool, address, flags)
        save_result(job_id, raw_output, parsed_data)
        create_findings_from_scan(job_id, job["target_id"], job["user_id"], tool, parsed_data)
        # Phase 4: NVD CVE enrichment for web tool findings
        if tool in ("nikto", "nuclei", "shodan", "abuseipdb"):
            enrich_findings_with_nvd(job_id)
        # Phase 3: auto-populate network_hosts after arp-scan
        if tool == "arp-scan":
            network_map_id = job["meta"].get("networkMapId")
            if network_map_id:
                populate_network_hosts(network_map_id, parsed_data.get("hosts", []))
        update_job_status(job_id, "completed")
        dispatch_scan_notification(job_id, job["user_id"], tool, address, "completed")
        logger.info(f"Scan job {job_id} completed ({tool} on {address})")
    except Exception as exc:
        logger.exception(f"Scan job {job_id} failed: {exc}")
        update_job_status(job_id, "failed", error_message=str(exc)[:500])
        dispatch_scan_notification(job_id, job.get("user_id", ""), tool, address, "failed")
        raise self.retry(exc=exc, countdown=30)


def dispatch_tool(tool: str, address: str, flags: str) -> tuple[str, dict]:
    handlers = {
        "nmap": run_nmap,
        "masscan": run_masscan,
        "arp-scan": run_arp_scan,
        "dns": run_dns,
        "nikto": run_nikto,
        "nuclei": run_nuclei,
        "whatweb": run_whatweb,
        "openssl": run_openssl,
        "testssl": run_testssl,
        "gobuster": run_gobuster,
        "amass": run_amass,
        "subfinder": run_subfinder,
        "whois": run_whois,
        "shodan": run_shodan,
        "virustotal": run_virustotal,
        "abuseipdb": run_abuseipdb,
        "ipinfo": run_ipinfo,
        "hibp": run_hibp,
    }
    if tool not in handlers:
        raise ValueError(f"Tool '{tool}' is not implemented")
    return handlers[tool](address, flags)


# ─── Phase 2: Port Scanners ───────────────────────────────────────────────────

def run_nmap(address: str, flags: str) -> tuple[str, dict]:
    cmd = ["nmap"] + (flags.split() if flags else ["-T4", "-F"]) + ["-oX", "-", address]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    raw = result.stdout or result.stderr
    parsed = parse_nmap_xml(raw)
    return raw, parsed


def parse_nmap_xml(xml_output: str) -> dict:
    try:
        import xml.etree.ElementTree as ET
        root = ET.fromstring(xml_output)
        hosts = []
        for host in root.findall("host"):
            addr_el = host.find("address[@addrtype='ipv4']")
            if addr_el is None:
                addr_el = host.find("address")
            status = host.find("status")
            hostnames_el = host.find("hostnames")
            ports_el = host.find("ports")
            os_el = host.find("os")

            hostname = None
            if hostnames_el is not None:
                hn = hostnames_el.find("hostname")
                if hn is not None:
                    hostname = hn.get("name")

            os_name = None
            if os_el is not None:
                osmatch = os_el.find("osmatch")
                if osmatch is not None:
                    os_name = osmatch.get("name")

            host_data = {
                "address": addr_el.get("addr") if addr_el is not None else None,
                "status": status.get("state") if status is not None else "unknown",
                "hostname": hostname,
                "os": os_name,
                "ports": [],
            }
            if ports_el is not None:
                for port in ports_el.findall("port"):
                    state_el = port.find("state")
                    service_el = port.find("service")
                    scripts = {}
                    for script in port.findall("script"):
                        scripts[script.get("id")] = script.get("output")
                    host_data["ports"].append({
                        "port": int(port.get("portid")),
                        "protocol": port.get("protocol"),
                        "state": state_el.get("state") if state_el is not None else "unknown",
                        "service": service_el.get("name") if service_el is not None else None,
                        "product": service_el.get("product") if service_el is not None else None,
                        "version": service_el.get("version") if service_el is not None else None,
                        "extrainfo": service_el.get("extrainfo") if service_el is not None else None,
                        "scripts": scripts if scripts else None,
                    })
            hosts.append(host_data)

        scan_info = root.find("scaninfo")
        run_stats = root.find("runstats/finished")
        return {
            "hosts": hosts,
            "scan_type": scan_info.get("type") if scan_info is not None else None,
            "protocol": scan_info.get("protocol") if scan_info is not None else None,
            "elapsed": run_stats.get("elapsed") if run_stats is not None else None,
        }
    except Exception as e:
        logger.warning(f"nmap XML parse failed: {e}")
        return {"raw": xml_output[:2000]}


def run_masscan(address: str, flags: str) -> tuple[str, dict]:
    cmd = ["masscan"] + (flags.split() if flags else ["--top-ports", "1000", "--rate", "1000"]) + [address, "-oJ", "-"]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    raw = result.stdout or result.stderr
    try:
        data = json.loads(raw) if raw.strip().startswith("[") else []
        return raw, {"results": data}
    except Exception:
        return raw, {"raw": raw[:2000]}


# ─── Phase 3: Network Discovery ──────────────────────────────────────────────

def run_arp_scan(address: str, flags: str = "") -> tuple[str, dict]:
    if address in ("localnet", "local", ""):
        cmd = ["arp-scan", "--localnet"]
    else:
        cmd = ["arp-scan", address]
    if flags:
        cmd += flags.split()
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    raw = result.stdout
    hosts = []
    for line in raw.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            ip = parts[0].strip()
            mac = parts[1].strip() if len(parts) > 1 else None
            vendor = parts[2].strip() if len(parts) > 2 else None
            if ip and re.match(r"^\d+\.\d+\.\d+\.\d+$", ip):
                hostname = _reverse_dns(ip)
                hosts.append({"ip": ip, "mac": mac, "vendor": vendor, "hostname": hostname})
    return raw, {"hosts": hosts, "count": len(hosts)}


def _reverse_dns(ip: str) -> str | None:
    try:
        result = subprocess.run(
            ["dig", "+short", "-x", ip],
            capture_output=True, text=True, timeout=5
        )
        hostname = result.stdout.strip().rstrip(".")
        return hostname if hostname else None
    except Exception:
        return None


def run_traceroute(address: str, flags: str = "") -> tuple[str, dict]:
    cmd = ["traceroute"] + (flags.split() if flags else ["-n", "-m", "20"]) + [address]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    raw = result.stdout or result.stderr
    hops = []
    for line in raw.splitlines():
        match = re.match(r"\s*(\d+)\s+([\d.]+|\*)", line)
        if match:
            hop_num = int(match.group(1))
            hop_ip = match.group(2)
            rtt_match = re.findall(r"(\d+\.?\d*)\s*ms", line)
            hops.append({
                "hop": hop_num,
                "ip": hop_ip if hop_ip != "*" else None,
                "rtt_ms": [float(r) for r in rtt_match],
                "timeout": hop_ip == "*",
            })
    return raw, {"hops": hops, "target": address}


def run_ping(address: str, flags: str = "") -> tuple[str, dict]:
    count = "4"
    if flags:
        parts = flags.split()
        count = parts[0] if parts else "4"
    cmd = ["ping", "-c", count, address]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    raw = result.stdout or result.stderr
    packet_match = re.search(r"(\d+) packets transmitted, (\d+) received", raw)
    rtt_match = re.search(r"rtt min/avg/max/mdev = ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+)", raw)
    return raw, {
        "host": address,
        "transmitted": int(packet_match.group(1)) if packet_match else None,
        "received": int(packet_match.group(2)) if packet_match else None,
        "packet_loss": (1 - int(packet_match.group(2)) / int(packet_match.group(1))) * 100
            if packet_match and int(packet_match.group(1)) > 0 else None,
        "rtt_min": float(rtt_match.group(1)) if rtt_match else None,
        "rtt_avg": float(rtt_match.group(2)) if rtt_match else None,
        "rtt_max": float(rtt_match.group(3)) if rtt_match else None,
    }


# ─── Phase 4: Web & Vulnerability Tools ──────────────────────────────────────

def run_nikto(address: str, flags: str = "") -> tuple[str, dict]:
    target = address if address.startswith("http") else f"http://{address}"
    cmd = ["nikto", "-h", target, "-Format", "json"] + (flags.split() if flags else [])
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    raw = result.stdout or result.stderr
    try:
        data = json.loads(raw)
        return raw, {"findings": data.get("vulnerabilities", []), "raw": data}
    except Exception:
        findings = []
        for line in raw.splitlines():
            if "+ " in line:
                findings.append(line.strip())
        return raw, {"findings": findings}


def run_nuclei(address: str, flags: str = "") -> tuple[str, dict]:
    target = address if address.startswith("http") else f"http://{address}"
    cmd = ["nuclei", "-u", target, "-json"] + (flags.split() if flags else ["-severity", "info,low,medium,high,critical"])
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    raw = result.stdout or result.stderr
    findings = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            finding = json.loads(line)
            findings.append({
                "template": finding.get("template-id"),
                "name": finding.get("info", {}).get("name"),
                "severity": finding.get("info", {}).get("severity"),
                "description": finding.get("info", {}).get("description"),
                "matched_at": finding.get("matched-at"),
                "tags": finding.get("info", {}).get("tags", []),
            })
        except json.JSONDecodeError:
            continue
    return raw, {"findings": findings, "count": len(findings)}


def run_whatweb(address: str, flags: str = "") -> tuple[str, dict]:
    target = address if address.startswith("http") else f"http://{address}"
    cmd = ["whatweb", "--log-json=-", target] + (flags.split() if flags else [])
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    raw = result.stdout or result.stderr
    try:
        data = json.loads(raw)
        if isinstance(data, list) and data:
            entry = data[0]
            plugins = entry.get("plugins", {})
            technologies = []
            for name, info in plugins.items():
                tech = {"name": name}
                if "version" in info:
                    tech["version"] = info["version"][0] if info["version"] else None
                if "string" in info:
                    tech["detail"] = info["string"][0] if info["string"] else None
                technologies.append(tech)
            return raw, {"target": entry.get("target"), "technologies": technologies, "http_status": entry.get("http_status")}
    except Exception:
        pass
    return raw, {"raw": raw[:2000]}


def run_openssl(address: str, flags: str = "") -> tuple[str, dict]:
    host = address.split(":")[0]
    port = address.split(":")[1] if ":" in address else "443"
    cmd = ["openssl", "s_client", "-connect", f"{host}:{port}", "-showcerts"]
    result = subprocess.run(cmd, input="Q\n", capture_output=True, text=True, timeout=30)
    raw = result.stdout or result.stderr
    cert_cmd = ["openssl", "s_client", "-connect", f"{host}:{port}", "-servername", host]
    cert_result = subprocess.run(cert_cmd, input="Q\n", capture_output=True, text=True, timeout=30)
    cert_raw = cert_result.stdout
    parsed = _parse_ssl_output(cert_raw, host)
    return raw + "\n" + cert_raw, parsed


def _parse_ssl_output(output: str, host: str) -> dict:
    result = {"host": host}
    subject_match = re.search(r"subject=(.+)", output)
    if subject_match:
        result["subject"] = subject_match.group(1).strip()
    issuer_match = re.search(r"issuer=(.+)", output)
    if issuer_match:
        result["issuer"] = issuer_match.group(1).strip()
    not_before = re.search(r"Not Before:\s*(.+)", output)
    not_after = re.search(r"Not After\s*:\s*(.+)", output)
    if not_before:
        result["not_before"] = not_before.group(1).strip()
    if not_after:
        result["not_after"] = not_after.group(1).strip()
    protocol_match = re.search(r"Protocol\s*:\s*(.+)", output)
    if protocol_match:
        result["protocol"] = protocol_match.group(1).strip()
    cipher_match = re.search(r"Cipher\s*:\s*(.+)", output)
    if cipher_match:
        result["cipher"] = cipher_match.group(1).strip()
    verify_match = re.search(r"Verify return code: (\d+) \((.+)\)", output)
    if verify_match:
        result["verify_code"] = int(verify_match.group(1))
        result["verify_message"] = verify_match.group(2).strip()
        result["valid"] = result["verify_code"] == 0
    return result


def run_testssl(address: str, flags: str = "") -> tuple[str, dict]:
    target = address if ":" in address else f"{address}:443"
    cmd = ["testssl.sh", "--json", "-"] + (flags.split() if flags else []) + [target]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    raw = result.stdout or result.stderr
    try:
        data = json.loads(raw)
        findings = []
        for item in data if isinstance(data, list) else []:
            if item.get("severity") not in ("OK", "INFO"):
                findings.append({
                    "id": item.get("id"),
                    "finding": item.get("finding"),
                    "severity": item.get("severity"),
                })
        return raw, {"findings": findings, "full": data}
    except Exception:
        return raw, {"raw": raw[:2000]}


def run_gobuster(address: str, flags: str = "") -> tuple[str, dict]:
    target = address if address.startswith("http") else f"http://{address}"
    wordlist = "/usr/share/wordlists/dirb/common.txt"
    cmd = ["gobuster", "dir", "-u", target, "-w", wordlist, "-o", "-"] + (flags.split() if flags else [])
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    raw = result.stdout or result.stderr
    found = []
    for line in raw.splitlines():
        match = re.match(r"(/\S+)\s+\(Status: (\d+)\)", line)
        if match:
            found.append({"path": match.group(1), "status": int(match.group(2))})
    return raw, {"found": found, "count": len(found)}


# ─── DNS / Recon ──────────────────────────────────────────────────────────────

def run_dns(domain: str, flags: str = "") -> tuple[str, dict]:
    record_type = flags.strip().upper() if flags.strip() in ("A", "MX", "TXT", "NS", "CNAME", "SOA", "AAAA", "PTR") else "A"
    cmd = ["dig", "+short", record_type, domain]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    raw = result.stdout
    records = [r.strip() for r in raw.splitlines() if r.strip()]
    return raw, {"domain": domain, "type": record_type, "records": records}


def run_amass(domain: str, flags: str = "") -> tuple[str, dict]:
    cmd = ["amass", "enum", "-passive", "-d", domain] + (flags.split() if flags else [])
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    raw = result.stdout or result.stderr
    subdomains = [line.strip() for line in raw.splitlines() if line.strip() and domain in line]
    return raw, {"domain": domain, "subdomains": subdomains, "count": len(subdomains)}


def run_subfinder(domain: str, flags: str = "") -> tuple[str, dict]:
    cmd = ["subfinder", "-d", domain, "-silent"] + (flags.split() if flags else [])
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    raw = result.stdout or result.stderr
    subdomains = [line.strip() for line in raw.splitlines() if line.strip()]
    return raw, {"domain": domain, "subdomains": subdomains, "count": len(subdomains)}


# ─── OSINT findings generators ───────────────────────────────────────────────

def _findings_from_abuseipdb(parsed_data: dict) -> list:
    findings = []
    score = parsed_data.get("abuseConfidenceScore", 0)
    is_tor = parsed_data.get("isTor", False)
    total_reports = parsed_data.get("totalReports", 0)
    if score >= 75:
        findings.append({
            "title": f"High-Abuse IP — AbuseIPDB confidence {score}%",
            "severity": "high",
            "description": f"AbuseIPDB reports {total_reports} abuse reports with {score}% confidence score. Country: {parsed_data.get('countryCode','?')}, ISP: {parsed_data.get('isp','?')}.",
            "remediation": "Block this IP at the firewall. Investigate any connections from this address in your logs.",
        })
    elif score >= 25:
        findings.append({
            "title": f"Suspicious IP — AbuseIPDB confidence {score}%",
            "severity": "medium",
            "description": f"AbuseIPDB reports {total_reports} abuse reports with {score}% confidence score.",
            "remediation": "Monitor traffic from this IP. Consider rate-limiting or geo-blocking.",
        })
    if is_tor:
        findings.append({
            "title": "TOR Exit Node Detected — AbuseIPDB",
            "severity": "medium",
            "description": "This IP is a known TOR exit node. Traffic originating from TOR may indicate anonymised malicious activity.",
            "remediation": "Block TOR exit node ranges if your application does not require anonymous access.",
        })
    return findings


def _findings_from_hibp(parsed_data: dict) -> list:
    findings = []
    breaches = parsed_data.get("breaches", [])
    count = parsed_data.get("breachCount", len(breaches))
    if count > 0:
        findings.append({
            "title": f"Domain found in {count} data breach(es) — HIBP",
            "severity": "high" if count >= 5 else "medium",
            "description": f"Have I Been Pwned reports this domain appears in {count} breach(es): {', '.join(breaches[:10])}.",
            "remediation": "Force password resets for all users. Enable breach monitoring. Review and rotate API credentials and service accounts.",
        })
    return findings


# ─── OSINT ────────────────────────────────────────────────────────────────────

def run_whois(address: str, flags: str = "") -> tuple[str, dict]:
    cmd = ["whois"] + (flags.split() if flags else []) + [address]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    raw = result.stdout or result.stderr
    parsed = {}
    important_fields = [
        "Registrar", "Registrar URL", "Registrant Organization",
        "Registrant Country", "Creation Date", "Updated Date",
        "Registry Expiry Date", "Name Server", "DNSSEC",
    ]
    for field in important_fields:
        match = re.search(rf"^{re.escape(field)}:\s*(.+)$", raw, re.MULTILINE | re.IGNORECASE)
        if match:
            parsed[field.lower().replace(" ", "_")] = match.group(1).strip()
    return raw, {"target": address, "parsed": parsed}


def run_shodan(address: str, flags: str = "") -> tuple[str, dict]:
    if not SHODAN_API_KEY:
        return "", {"error": "SHODAN_API_KEY not configured"}
    try:
        import urllib.request, urllib.parse
        url = f"https://api.shodan.io/shodan/host/{urllib.parse.quote(address)}?key={SHODAN_API_KEY}"
        with urllib.request.urlopen(url, timeout=30) as resp:
            data = json.loads(resp.read().decode())
        raw = json.dumps(data, indent=2)
        return raw, {
            "ip": data.get("ip_str"),
            "org": data.get("org"),
            "country": data.get("country_name"),
            "city": data.get("city"),
            "isp": data.get("isp"),
            "asn": data.get("asn"),
            "ports": data.get("ports", []),
            "hostnames": data.get("hostnames", []),
            "vulns": list(data.get("vulns", {}).keys()),
            "os": data.get("os"),
            "last_update": data.get("last_update"),
        }
    except Exception as exc:
        return "", {"error": str(exc)}


def run_virustotal(address: str, flags: str = "") -> tuple[str, dict]:
    if not VIRUSTOTAL_API_KEY:
        return "", {"error": "VIRUSTOTAL_API_KEY not configured"}
    try:
        import urllib.request, ipaddress
        try:
            ipaddress.ip_address(address)
            resource_type = "ip_addresses"
        except ValueError:
            resource_type = "domains"
        url = f"https://www.virustotal.com/api/v3/{resource_type}/{address}"
        req = urllib.request.Request(url, headers={"x-apikey": VIRUSTOTAL_API_KEY})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
        raw = json.dumps(data, indent=2)
        attrs = data.get("data", {}).get("attributes", {})
        stats = attrs.get("last_analysis_stats", {})
        return raw, {
            "target": address,
            "malicious": stats.get("malicious", 0),
            "suspicious": stats.get("suspicious", 0),
            "harmless": stats.get("harmless", 0),
            "undetected": stats.get("undetected", 0),
            "reputation": attrs.get("reputation"),
        }
    except Exception as exc:
        return "", {"error": str(exc)}


def run_abuseipdb(address: str, flags: str = "") -> tuple[str, dict]:
    if not ABUSEIPDB_API_KEY:
        return "", {"error": "ABUSEIPDB_API_KEY not configured"}
    try:
        import urllib.parse as _up
        params = _up.urlencode({"ipAddress": address, "maxAgeInDays": "90"})
        url = f"https://api.abuseipdb.com/api/v2/check?{params}"
        req = _urllib_request.Request(
            url,
            headers={"Key": ABUSEIPDB_API_KEY, "Accept": "application/json"},
        )
        with _urllib_request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
        d = data.get("data", {})
        return json.dumps(data, indent=2), {
            "ip": d.get("ipAddress"),
            "isPublic": d.get("isPublic"),
            "isTor": d.get("isTor", False),
            "abuseConfidenceScore": d.get("abuseConfidenceScore", 0),
            "countryCode": d.get("countryCode"),
            "usageType": d.get("usageType"),
            "isp": d.get("isp"),
            "domain": d.get("domain"),
            "totalReports": d.get("totalReports", 0),
            "numDistinctUsers": d.get("numDistinctUsers", 0),
            "lastReportedAt": d.get("lastReportedAt"),
        }
    except Exception as exc:
        return "", {"error": str(exc)}


def run_ipinfo(address: str, flags: str = "") -> tuple[str, dict]:
    try:
        import urllib.parse as _up
        token_param = f"?token={IPINFO_TOKEN}" if IPINFO_TOKEN else ""
        url = f"https://ipinfo.io/{_up.quote(address)}/json{token_param}"
        req = _urllib_request.Request(url, headers={"Accept": "application/json", "User-Agent": "CyberLab/1.0"})
        with _urllib_request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
        return json.dumps(data, indent=2), {
            "ip": data.get("ip"),
            "hostname": data.get("hostname"),
            "city": data.get("city"),
            "region": data.get("region"),
            "country": data.get("country"),
            "loc": data.get("loc"),
            "org": data.get("org"),
            "timezone": data.get("timezone"),
            "postal": data.get("postal"),
        }
    except Exception as exc:
        return "", {"error": str(exc)}


def run_hibp(address: str, flags: str = "") -> tuple[str, dict]:
    if not HIBP_API_KEY:
        return "", {"error": "HIBP_API_KEY not configured"}
    try:
        import urllib.parse as _up
        domain = address.replace("https://", "").replace("http://", "").split("/")[0]
        url = f"https://haveibeenpwned.com/api/v3/breacheddomain/{_up.quote(domain)}"
        req = _urllib_request.Request(
            url,
            headers={"hibp-api-key": HIBP_API_KEY, "User-Agent": "CyberLab/1.0"},
        )
        try:
            with _urllib_request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode())
            all_breaches: list[str] = []
            for _, breach_list in data.items():
                all_breaches.extend(breach_list)
            unique = list(set(all_breaches))
            return json.dumps(data, indent=2), {
                "domain": domain,
                "breachCount": len(unique),
                "breaches": unique[:50],
            }
        except Exception as e:
            if "404" in str(e):
                return "", {"domain": domain, "breachCount": 0, "breaches": []}
            raise
    except Exception as exc:
        return "", {"error": str(exc)}


# ─── Phase 8: Notification Dispatch ──────────────────────────────────────────

API_URL = os.environ.get("API_URL", "")
INTERNAL_NOTIFY_SECRET = os.environ.get("INTERNAL_NOTIFY_SECRET", "")


def count_critical_findings(job_id: str) -> int:
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) FROM findings WHERE scan_job_id = %s AND severity = 'critical'",
                (job_id,),
            )
            return cur.fetchone()[0] or 0
    except Exception:
        return 0
    finally:
        conn.close()


def dispatch_scan_notification(job_id: str, user_id: str, tool: str, address: str, status: str):
    """POST to the API's internal notify endpoint after a scan completes or fails."""
    if not API_URL or not INTERNAL_NOTIFY_SECRET or not user_id:
        return
    try:
        critical_count = count_critical_findings(job_id) if status == "completed" else 0
        body = json.dumps({
            "userId": user_id,
            "jobId": job_id,
            "tool": tool,
            "address": address,
            "status": status,
            "criticalCount": critical_count,
        }).encode()
        req = _urllib_request.Request(
            f"{API_URL.rstrip('/')}/api/notify/internal",
            data=body,
            headers={
                "Content-Type": "application/json",
                "x-internal-secret": INTERNAL_NOTIFY_SECRET,
            },
            method="POST",
        )
        with _urllib_request.urlopen(req, timeout=8):
            pass
    except Exception as exc:
        logger.debug(f"Notification dispatch skipped: {exc}")


# ─── Phase 8: Schedule Poller ─────────────────────────────────────────────────

def _compute_next_run(cron_expr: str):
    try:
        from croniter import croniter
        return croniter(cron_expr, datetime.now(timezone.utc)).get_next(datetime)
    except Exception:
        from datetime import timedelta
        return datetime.now(timezone.utc) + timedelta(hours=24)


def _schedule_poller():
    """Background thread: polls schedules table every 60s and enqueues due jobs."""
    import time
    logger.info("Schedule poller started")
    while True:
        try:
            conn = get_db()
            try:
                now = datetime.now(timezone.utc)
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT s.id, s.user_id, s.target_id, s.tool,
                               s.flags, s.cron_expression
                        FROM schedules s
                        JOIN targets t ON t.id = s.target_id
                        WHERE s.enabled = TRUE
                          AND (s.next_run_at IS NULL OR s.next_run_at <= %s)
                        """,
                        (now,),
                    )
                    due = cur.fetchall()

                for row in due:
                    sid, user_id, target_id, tool, flags_json, cron_expr = row
                    try:
                        flags = (flags_json or {}).get("flags", "") if isinstance(flags_json, dict) else ""
                        with conn.cursor() as cur:
                            cur.execute(
                                """
                                INSERT INTO scan_jobs
                                    (id, user_id, target_id, tool, flags, status, created_at, updated_at)
                                VALUES (gen_random_uuid(), %s, %s, %s, %s, 'pending', %s, %s)
                                RETURNING id
                                """,
                                (user_id, target_id, tool, flags, now, now),
                            )
                            job_id = str(cur.fetchone()[0])
                        conn.commit()
                        run_scan.delay(job_id)
                        logger.info(f"Scheduled scan enqueued: {tool} (schedule {sid})")
                        next_run = _compute_next_run(cron_expr)
                        with conn.cursor() as cur:
                            cur.execute(
                                "UPDATE schedules SET last_run_at=%s, next_run_at=%s, updated_at=%s WHERE id=%s",
                                (now, next_run, now, sid),
                            )
                        conn.commit()
                    except Exception as exc:
                        logger.warning(f"Failed to enqueue schedule {sid}: {exc}")
                        try:
                            conn.rollback()
                        except Exception:
                            pass
            finally:
                conn.close()
        except Exception as exc:
            logger.warning(f"Schedule poller error: {exc}")
        time.sleep(60)


threading.Thread(target=_schedule_poller, daemon=True).start()
