FROM python:3.12-slim

ARG CACHEBUST=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    nmap \
    arp-scan \
    iputils-ping \
    traceroute \
    dnsutils \
    netcat-openbsd \
    curl \
    wget \
    whois \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

CMD ["celery", "-A", "worker", "worker", "--loglevel=info", "--concurrency=4"]
