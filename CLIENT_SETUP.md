# Quantus Node Logging Setup

Configure Quantus Network services to send logs to Graylog.

---

## Same-host setup (Graylog on this machine)

Add logging to your existing `docker-compose.yml`:

```yaml
services:
  quantus-node:
    image: ghcr.io/quantus-network/quantus-node:v0.4.2
    container_name: quantus-node
    restart: unless-stopped
    command: >
      --validator
      --base-path /var/lib/quantus
      --chain dirac
      --node-key-file /var/lib/quantus/node_key
      --rewards-address qznYQKUeV5un22rXh7CCQB7Bsac74jynVDs2qbHk1hpPMjocB
      --name a1_dirac
      --execution native-else-wasm
      --wasm-execution compiled
      --db-cache 2048
      --unsafe-rpc-external
      --rpc-cors all
      --in-peers 256
      --out-peers 256
      --prometheus-external
    volumes:
      - ./quantus_node_data:/var/lib/quantus:z
    ports:
      - "30333:30333"
      - "9944:9944"
      - "9615:9615"
    
    # GELF logging:
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
        tag: "quantus-${NODE_NAME:-a1_dirac}"
        labels: "node_type,chain,region,environment,server"
        gelf-compression-type: "gzip"
        mode: "non-blocking"
        max-buffer-size: "4m"
    
    # Labels (visible in Graylog):
    labels:
      node_type: "validator"
      chain: "dirac"
      region: "europe"
      environment: "production"
      server: "server-01"
    
    environment:
      - NODE_NAME=a1_dirac
    
    networks:
      - default
      - graylog_network

networks:
  graylog_network:
    external: true
    name: logs_graylog
```

**What changed:**
1. Added `logging` section with GELF driver
2. Added `labels` for filtering in Graylog
3. Added `networks` to connect to Graylog

---

## Remote fleet setup (DO / Tailscale)

Use this when containers run on a different host than Graylog (e.g. Subsquid on DigitalOcean, Graylog on Hostinger). Ship GELF over **Tailscale** — do not join the `logs_graylog` Docker network.

### Graylog host checklist

1. Tailscale up on the Graylog host (same tailnet as fleet hosts)
2. Set `GRAYLOG_GELF_BIND_TAILSCALE` in `.env` to this host’s Tailscale IPv4 (`tailscale ip -4`)
3. Compose publishes GELF UDP on **localhost + Tailscale only** (not `0.0.0.0` / public `eth0`)
4. Firewall: allow **UDP/12201** from Tailscale (`100.64.0.0/10` or interface `tailscale0`)
5. Verify: `ss -ulnp | grep 12201` shows `127.0.0.1` and `100.x…`, not `0.0.0.0`
6. Probe from a non-Tailscale host to the public IP — message must **not** appear in Graylog

### Client pattern

Point `gelf-address` at the Graylog Tailscale IP or MagicDNS name. Keep `mode: non-blocking` so a Graylog outage does not stall apps.

```yaml
services:
  example:
    # ... image, ports, volumes ...
    logging:
      driver: gelf
      options:
        gelf-address: "udp://<graylog-tailscale-ip-or-magicdns>:12201"
        tag: "subsquid-processor-blue"
        labels: "project,service,color,host"
        gelf-compression-type: "gzip"
        mode: "non-blocking"
        max-buffer-size: "4m"
    labels:
      project: "subsquid"
      service: "processor"
      color: "blue"
      host: "subsquid-proc-1"
```

No `logs_graylog` external network.

### Preflight probe (from a fleet host)

```bash
echo '{"version":"1.1","host":"probe","short_message":"gelf-ok","level":1}' \
  | nc -u -w1 <graylog-tailscale-ip> 12201
```

Confirm `gelf-ok` appears in the Graylog UI before enabling fleet-wide shipping.

Fleet wiring for Subsquid is in the IaC Ansible project (`graylog_gelf_address` in the project vault; `graylog_logging_enabled` per project).

---

## Start (same-host)

```bash
docker compose up -d
```

Check logs in Graylog: **http://localhost:9000** → Search for `tag:quantus-*`

---

## Useful Searches

```
# All nodes
tag:quantus-*

# Errors
tag:quantus-* AND (level:3 OR message:/ERROR|WARN/i)

# Block finalization
tag:quantus-* AND message:/Finalized|Imported/

# Consensus
tag:quantus-* AND message:/grandpa|babe/i

# Network
tag:quantus-* AND message:/peer|connection/i

# By region
_region:europe

# By server
_server:server-01

# Remote fleets (IaC labels)
project:subsquid
service:processor
service:hasura
_host:subsquid-proc-1
```

---

## Troubleshooting

### Logs not appearing?

```bash
# Check Docker logging config
docker inspect quantus-node | grep -A 15 LogConfig

# Same-host: shared Docker network
docker network inspect logs_graylog | grep quantus-node

# Same-host GELF probe
echo '{"version":"1.1","host":"test","short_message":"Test","level":1}' | nc -u localhost 12201

# Remote: Tailscale + firewall on Graylog host; probe from fleet host (see above)
```

### Container won't start?

```bash
# Start Graylog first
cd /path/to/graylog
docker compose up -d

# Then start node
cd /path/to/your/node
docker compose up -d
```

---

See [GRAYLOG_SETUP.md](GRAYLOG_SETUP.md) for Graylog management.
