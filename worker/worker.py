"""
CyberLab Scanner Worker
Picks scan jobs from Redis queue, runs tools inside this container, writes results back to DB.
Phase 1: job lifecycle only. Actual tool execution added in Phase 3 (Nmap Port Scanner).
"""
import os
import json
import logging
import subprocess
from datetime import datetime, timezone
from celery import Celery
import psycopg2
from psycopg2.extras import Json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
DATABASE_URL = os.environ.get("DATABASE_URL", "")

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
    """Route to the correct tool handler. Extended in Phase 3+."""
    if tool == "nmap":
        return run_nmap(address, flags)
    elif tool == "arp-scan":
        return run_arp_scan(address)
    elif tool == "dns":
        return run_dns(address, flags)
    else:
        raise ValueError(f"Tool '{tool}' not yet implemented in worker")


def run_nmap(address: str, flags: str) -> tuple[str, dict]:
    cmd = ["nmap"] + (flags.split() if flags else ["-T4", "-F"]) + ["-oX", "-", address]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    raw = result.stdout or result.stderr
    parsed = parse_nmap_xml(raw)
    return raw, parsed


def parse_nmap_xml(xml_output: str) -> dict:
    """Basic nmap XML parser. Enhanced in Phase 3."""
    try:
        import xml.etree.ElementTree as ET
        root = ET.fromstring(xml_output)
        hosts = []
        for host in root.findall("host"):
            addr = host.find("address")
            status = host.find("status")
            ports_el = host.find("ports")
            host_data = {
                "address": addr.get("addr") if addr is not None else None,
                "status": status.get("state") if status is not None else "unknown",
                "ports": [],
            }
            if ports_el is not None:
                for port in ports_el.findall("port"):
                    state_el = port.find("state")
                    service_el = port.find("service")
                    host_data["ports"].append({
                        "port": port.get("portid"),
                        "protocol": port.get("protocol"),
                        "state": state_el.get("state") if state_el is not None else "unknown",
                        "service": service_el.get("name") if service_el is not None else None,
                        "version": f"{service_el.get('product', '')} {service_el.get('version', '')}".strip() if service_el is not None else None,
                    })
            hosts.append(host_data)
        return {"hosts": hosts}
    except Exception:
        return {"raw": xml_output[:2000]}


def run_arp_scan(subnet: str) -> tuple[str, dict]:
    cmd = ["arp-scan", "--localnet"] if subnet in ("localnet", "local") else ["arp-scan", subnet]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    raw = result.stdout
    hosts = []
    for line in raw.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            ip = parts[0].strip()
            mac = parts[1].strip() if len(parts) > 1 else None
            vendor = parts[2].strip() if len(parts) > 2 else None
            if ip and ip[0].isdigit():
                hosts.append({"ip": ip, "mac": mac, "vendor": vendor})
    return raw, {"hosts": hosts}


def run_dns(domain: str, flags: str) -> tuple[str, dict]:
    record_type = flags.strip() if flags.strip() in ("A", "MX", "TXT", "NS", "CNAME", "SOA", "AAAA") else "A"
    cmd = ["dig", "+short", record_type, domain]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    raw = result.stdout
    records = [r.strip() for r in raw.splitlines() if r.strip()]
    return raw, {"domain": domain, "type": record_type, "records": records}
