FROM python:3.12-slim

ARG CACHEBUST=1

# Install system tools (apt-available)
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
    whatweb \
    gobuster \
    git \
    ruby \
    perl \
    libnet-ssleay-perl \
    openssl \
    ca-certificates \
    unzip \
    libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

# Install nikto from source (not available in Debian Trixie repos)
RUN git clone --depth 1 https://github.com/sullo/nikto.git /opt/nikto \
    && ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto \
    && chmod +x /opt/nikto/program/nikto.pl

# Install testssl.sh
RUN git clone --depth 1 https://github.com/drwetter/testssl.sh.git /opt/testssl.sh \
    && ln -s /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh \
    && chmod +x /opt/testssl.sh/testssl.sh

# Install nuclei
RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then NUCLEI_ARCH="amd64"; elif [ "$ARCH" = "arm64" ]; then NUCLEI_ARCH="arm64"; else NUCLEI_ARCH="amd64"; fi \
    && curl -sL "https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_$(curl -s https://api.github.com/repos/projectdiscovery/nuclei/releases/latest | grep tag_name | cut -d'"' -f4 | tr -d 'v')_linux_${NUCLEI_ARCH}.zip" -o /tmp/nuclei.zip \
    && unzip -o /tmp/nuclei.zip nuclei -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/nuclei \
    && rm /tmp/nuclei.zip

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Run as an unprivileged user. The scanners that need raw sockets get the
# single capability they use (CAP_NET_RAW, which containers grant by
# default) instead of the whole container running as root. NMAP_PRIVILEGED
# tells nmap to use its raw-socket code paths without checking for uid 0.
RUN useradd --system --create-home --home-dir /home/worker --shell /usr/sbin/nologin worker \
    && setcap cap_net_raw+eip /usr/bin/nmap \
    && setcap cap_net_raw+eip /usr/sbin/arp-scan \
    && setcap cap_net_raw+eip "$(readlink -f "$(command -v traceroute)")" \
    && chown -R worker:worker /app /opt/nikto /opt/testssl.sh
ENV HOME=/home/worker \
    NMAP_PRIVILEGED=1
USER worker
# Templates live under the runtime user's home; refresh them there.
RUN nuclei -update-templates 2>/dev/null || true

EXPOSE 8080

CMD ["celery", "-A", "worker", "worker", "--loglevel=info", "--concurrency=4"]
