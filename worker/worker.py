"""
CyberLab Scanner Worker
Picks scan jobs from Redis queue, runs tools inside this container, writes results back to DB.
Phase 1-4: Nmap, arp-scan, DNS, traceroute, ping, nikto, nuclei, whatweb, testssl, whois, shodan, virustotal
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

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
DATABASE_URL = os.environ.get("DATABASE_URL", "")

SHODAN_API_KEY = os.environ.get("SHODAN_API_KEY", "")
VIRUSTOTAL_API_KEY = os.environ.get("VIRUSTOTAL_API_KEY", "")
ABUSEIPDB_API_KEY = os.environ.get("ABUSEIPDB_API_KEY", "")

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


def get_db():
    return psycopg2.connect(DATABASE_URL)


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
                       t.address, t.type
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
            }
    finally:
        conn.close()


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
        update_job_status(job_id, "completed")
        logger.info(f"Scan job {job_id} completed")
    except Exception as exc:
        logger.exception(f"Scan job {job_id} failed: {exc}")
        update_job_status(job_id, "failed", error_message=str(exc))
        raise self.retry(exc=exc, countdown=30)


def dispatch_tool(tool: str, address: str, flags: str) -> tuple[str, dict]:
    """Route to the correct tool handler."""
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
    }
    if tool not in handlers:
        raise ValueError(f"Tool '{tool}' is not implemented")
    return handlers[tool](address, flags)


# ─── Phase 2: Port Scanner ───────────────────────────────────────────────────

def run_nmap(address: str, flags: str) -> tuple[str, dict]:
    cmd = ["nmap"] + (flags.split() if flags else ["-T4", "-F"]) + ["-oX", "-", address]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    raw = result.stdout or result.stderr
    parsed = parse_nmap_xml(raw)
    return raw, parsed


def parse_nmap_xml(xml_output: str) -> dict:
    """Parse nmap XML output into structured data."""
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

        # Also extract scan metadata
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
    """Masscan — fast port scanner, lab only."""
    cmd = ["masscan"] + (flags.split() if flags else ["--top-ports", "1000", "--rate", "1000"]) + [address, "-oJ", "-"]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    raw = result.stdout or result.stderr
    try:
        data = json.loads(raw) if raw.strip().startswith("[") else []
        return raw, {"results": data}
    except Exception:
        return raw, {"raw": raw[:2000]}


# ─── Phase 3: Network Mapper ─────────────────────────────────────────────────

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
                # Try to resolve hostname
                hostname = _reverse_dns(ip)
                hosts.append({"ip": ip, "mac": mac, "vendor": vendor, "hostname": hostname})
    return raw, {"hosts": hosts, "count": len(hosts)}


def _reverse_dns(ip: str) -> str | None:
    """Quick reverse DNS lookup."""
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
            # Extract RTT
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
    # Parse ping summary
    packet_match = re.search(r"(\d+) packets transmitted, (\d+) received", raw)
    rtt_match = re.search(r"rtt min/avg/max/mdev = ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+)", raw)
    return raw, {
        "host": address,
        "transmitted": int(packet_match.group(1)) if packet_match else None,
        "received": int(packet_match.group(2)) if packet_match else None,
        "packet_loss": (1 - int(packet_match.group(2)) / int(packet_match.group(1))) * 100 if packet_match and int(packet_match.group(1)) > 0 else None,
        "rtt_min": float(rtt_match.group(1)) if rtt_match else None,
        "rtt_avg": float(rtt_match.group(2)) if rtt_match else None,
        "rtt_max": float(rtt_match.group(3)) if rtt_match else None,
    }


# ─── Phase 4: Web & Vulnerability Tools ──────────────────────────────────────

def run_nikto(address: str, flags: str = "") -> tuple[str, dict]:
    """Nikto web scanner."""
    target = address if address.startswith("http") else f"http://{address}"
    cmd = ["nikto", "-h", target, "-Format", "json"] + (flags.split() if flags else [])
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    raw = result.stdout or result.stderr
    try:
        data = json.loads(raw)
        return raw, {"findings": data.get("vulnerabilities", []), "raw": data}
    except Exception:
        # Parse text output
        findings = []
        for line in raw.splitlines():
            if "+ " in line:
                findings.append(line.strip())
        return raw, {"findings": findings}


def run_nuclei(address: str, flags: str = "") -> tuple[str, dict]:
    """Nuclei vulnerability scanner."""
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
    """WhatWeb technology detection."""
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
    """OpenSSL certificate info."""
    host = address.split(":")[0]
    port = address.split(":")[1] if ":" in address else "443"
    cmd = ["openssl", "s_client", "-connect", f"{host}:{port}", "-showcerts"]
    result = subprocess.run(
        cmd, input="Q\n", capture_output=True, text=True, timeout=30
    )
    raw = result.stdout or result.stderr

    # Extract cert info
    cert_cmd = ["openssl", "s_client", "-connect", f"{host}:{port}", "-servername", host]
    cert_result = subprocess.run(
        cert_cmd, input="Q\n", capture_output=True, text=True, timeout=30
    )
    cert_raw = cert_result.stdout

    # Parse cert details
    parsed = _parse_ssl_output(cert_raw, host)
    return raw + "\n" + cert_raw, parsed


def _parse_ssl_output(output: str, host: str) -> dict:
    result = {"host": host}
    # Subject
    subject_match = re.search(r"subject=(.+)", output)
    if subject_match:
        result["subject"] = subject_match.group(1).strip()
    # Issuer
    issuer_match = re.search(r"issuer=(.+)", output)
    if issuer_match:
        result["issuer"] = issuer_match.group(1).strip()
    # Dates (look in cert text)
    not_before = re.search(r"Not Before:\s*(.+)", output)
    not_after = re.search(r"Not After\s*:\s*(.+)", output)
    if not_before:
        result["not_before"] = not_before.group(1).strip()
    if not_after:
        result["not_after"] = not_after.group(1).strip()
    # Protocol
    protocol_match = re.search(r"Protocol\s*:\s*(.+)", output)
    if protocol_match:
        result["protocol"] = protocol_match.group(1).strip()
    # Cipher
    cipher_match = re.search(r"Cipher\s*:\s*(.+)", output)
    if cipher_match:
        result["cipher"] = cipher_match.group(1).strip()
    # Verify result
    verify_match = re.search(r"Verify return code: (\d+) \((.+)\)", output)
    if verify_match:
        result["verify_code"] = int(verify_match.group(1))
        result["verify_message"] = verify_match.group(2).strip()
        result["valid"] = result["verify_code"] == 0
    return result


def run_testssl(address: str, flags: str = "") -> tuple[str, dict]:
    """testssl.sh TLS analysis."""
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
    """Gobuster directory/file brute force (lab targets only)."""
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


# ─── Phase 3: DNS Tools ───────────────────────────────────────────────────────

def run_dns(domain: str, flags: str = "") -> tuple[str, dict]:
    """DNS lookup with dig."""
    record_type = flags.strip().upper() if flags.strip() in ("A", "MX", "TXT", "NS", "CNAME", "SOA", "AAAA", "PTR") else "A"
    cmd = ["dig", "+short", record_type, domain]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    raw = result.stdout
    records = [r.strip() for r in raw.splitlines() if r.strip()]
    return raw, {"domain": domain, "type": record_type, "records": records}


def run_amass(domain: str, flags: str = "") -> tuple[str, dict]:
    """Amass subdomain enumeration."""
    cmd = ["amass", "enum", "-passive", "-d", domain] + (flags.split() if flags else [])
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    raw = result.stdout or result.stderr
    subdomains = [line.strip() for line in raw.splitlines() if line.strip() and domain in line]
    return raw, {"domain": domain, "subdomains": subdomains, "count": len(subdomains)}


def run_subfinder(domain: str, flags: str = "") -> tuple[str, dict]:
    """Subfinder passive subdomain discovery."""
    cmd = ["subfinder", "-d", domain, "-silent"] + (flags.split() if flags else [])
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    raw = result.stdout or result.stderr
    subdomains = [line.strip() for line in raw.splitlines() if line.strip()]
    return raw, {"domain": domain, "subdomains": subdomains, "count": len(subdomains)}


# ─── Phase 6: OSINT ──────────────────────────────────────────────────────────

def run_whois(address: str, flags: str = "") -> tuple[str, dict]:
    """WHOIS lookup."""
    cmd = ["whois"] + (flags.split() if flags else []) + [address]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    raw = result.stdout or result.stderr

    parsed = {}
    important_fields = [
        "Registrar", "Registrar URL", "Registrant Organization",
        "Registrant Country", "Creation Date", "Updated Date",
        "Registry Expiry Date", "Name Server", "DNSSEC",
        "Registrant Email", "Admin Email",
    ]
    for field in important_fields:
        match = re.search(rf"^{re.escape(field)}:\s*(.+)$", raw, re.MULTILINE | re.IGNORECASE)
        if match:
            parsed[field.lower().replace(" ", "_")] = match.group(1).strip()

    return raw, {"target": address, "parsed": parsed}


def run_shodan(address: str, flags: str = "") -> tuple[str, dict]:
    """Shodan host lookup via API."""
    if not SHODAN_API_KEY:
        return "", {"error": "SHODAN_API_KEY not configured"}
    try:
        import urllib.request
        import urllib.parse
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
    """VirusTotal IP/domain reputation lookup."""
    if not VIRUSTOTAL_API_KEY:
        return "", {"error": "VIRUSTOTAL_API_KEY not configured"}
    try:
        import urllib.request
        import ipaddress
        # Determine if IP or domain
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
            "community_score": attrs.get("total_votes", {}).get("harmless", 0) - attrs.get("total_votes", {}).get("malicious", 0),
        }
    except Exception as exc:
        return "", {"error": str(exc)}
