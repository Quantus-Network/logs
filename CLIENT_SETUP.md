# Quantus Node Logging Setup

Configure Quantus Network validator nodes to send logs to Graylog.

---

## Configuration

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

## Start

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
```

---

## Troubleshooting

### Logs not appearing?

```bash
# Check Docker logging config
docker inspect quantus-node | grep -A 15 LogConfig

# Check network
docker network inspect logs_graylog | grep quantus-node

# Test GELF
echo '{"version":"1.1","host":"test","short_message":"Test","level":1}' | nc -u localhost 12201
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
