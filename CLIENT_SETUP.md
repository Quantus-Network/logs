# Client Setup Guide - Send Logs to Graylog

Guide for configuring applications and services to send logs to Graylog.

## 📋 Table of Contents

- [Substrate/Blockchain Nodes](#substrate--blockchain-nodes)
- [Docker Containers](#docker-containers)
- [Web Servers](#web-servers-nginx--apache)
- [Programming Languages](#programming-languages)
- [System Logs](#system-logs-syslog)
- [Kubernetes](#kubernetes)
- [Custom Applications](#custom-applications)

---

## 🔗 Substrate / Blockchain Nodes

Perfect for aggregating logs from multiple blockchain nodes.

### Prerequisites

1. **Graylog running** - see [GRAYLOG_SETUP.md](GRAYLOG_SETUP.md)
2. **GELF UDP Input configured** in Graylog (port 12201)

### Configuration

#### Option A: Separate Docker Compose Files

If your Substrate nodes are in a separate `docker-compose.yml`:

```yaml
# substrate-nodes/docker-compose.yml

services:
  substrate-validator-1:
    image: parity/polkadot:latest
    container_name: validator-1
    command: |
      --validator
      --name "Validator 1"
      --chain polkadot
    ports:
      - "30333:30333"
      - "9933:9933"
      - "9944:9944"
    volumes:
      - validator1-data:/data
    
    # Add logging configuration:
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
        tag: "substrate-validator-1"
        gelf-compression-type: "none"
        labels: "node_type,chain,environment"
    
    labels:
      node_type: "validator"
      chain: "polkadot"
      environment: "production"
    
    # Connect to Graylog network:
    networks:
      - substrate-network
      - graylog_network
    
    restart: always

  substrate-validator-2:
    image: parity/polkadot:latest
    container_name: validator-2
    command: |
      --validator
      --name "Validator 2"
      --chain polkadot
    
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
        tag: "substrate-validator-2"
    
    networks:
      - substrate-network
      - graylog_network
    
    restart: always

networks:
  substrate-network:
    driver: bridge
  
  # Connect to external Graylog network:
  graylog_network:
    external: true
    name: logs_graylog

volumes:
  validator1-data:
  validator2-data:
```

#### Option B: Same Docker Compose File

If everything is in one `docker-compose.yml`:

```yaml
services:
  substrate-node:
    image: parity/polkadot:latest
    
    logging:
      driver: gelf
      options:
        gelf-address: "udp://graylog:12201"  # Use service name
        tag: "substrate-node"
    
    networks:
      - graylog  # Same network as Graylog services

networks:
  graylog:
    driver: bridge
```

### Advanced Configuration with Custom Fields

```yaml
services:
  substrate-node:
    image: parity/polkadot:latest
    
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
        tag: "substrate-${NODE_NAME}"
        
        # Add environment variables as log fields:
        env: "NODE_NAME,CHAIN_SPEC,NODE_ROLE"
        
        # Add labels as log fields:
        labels: "node_type,chain,region,environment"
        
        # Performance tuning:
        gelf-compression-type: "gzip"  # Enable compression for high volume
        gelf-buffer-size: "8192"       # Increase buffer
        mode: "non-blocking"            # Don't block if Graylog unavailable
        max-buffer-size: "4m"           # Buffer size for non-blocking mode
    
    environment:
      - NODE_NAME=validator-tokyo-01
      - CHAIN_SPEC=polkadot
      - NODE_ROLE=validator
    
    labels:
      node_type: "validator"
      chain: "polkadot"
      region: "asia-pacific"
      environment: "production"
```

### Start and Verify

```bash
# Start your nodes
docker compose up -d

# Verify logging driver is configured
docker inspect substrate-validator-1 | grep -A 10 LogConfig

# Check Graylog
# Go to: http://localhost:9000
# Search for: tag:substrate-*
```

### Useful Graylog Searches for Substrate

```
# All Substrate nodes
tag:substrate-*

# Errors only
tag:substrate-* AND (level:3 OR message:/ERROR|CRITICAL|FATAL/i)

# Specific node
tag:substrate-validator-1

# Block finalization
tag:substrate-* AND message:/Finalized|Imported/

# Network issues
tag:substrate-* AND message:/peer|connection|network/i

# Consensus issues
tag:substrate-* AND message:/consensus|grandpa|babe/i

# By chain
_chain:polkadot

# By node type
_node_type:validator
```

---

## 🐳 Docker Containers

Send logs from any Docker container to Graylog.

### Simple Configuration

```yaml
services:
  your-app:
    image: your-app:latest
    
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
        tag: "your-app"
```

### Multiple Applications

```yaml
services:
  frontend:
    image: nginx:alpine
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
        tag: "frontend"
  
  backend:
    image: your-backend:latest
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
        tag: "backend-api"
  
  database:
    image: postgres:15
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
        tag: "postgresql"
```

### With Environment-Specific Tags

```yaml
services:
  app:
    image: myapp:latest
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
        tag: "myapp-${ENV:-dev}"  # Uses $ENV or defaults to 'dev'
    environment:
      - ENV=production
```

---

## 🌐 Web Servers (Nginx & Apache)

### Nginx

#### Using Syslog

Edit `/etc/nginx/nginx.conf`:

```nginx
http {
    # Send access logs to Graylog
    access_log syslog:server=localhost:1514,facility=local7,tag=nginx,severity=info;
    
    # Send error logs to Graylog
    error_log syslog:server=localhost:1514,facility=local7,tag=nginx,severity=error;
    
    # Rest of your configuration...
}
```

#### Using Docker GELF

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
        tag: "nginx-web"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
```

### Apache

Edit `/etc/httpd/conf/httpd.conf` (or `/etc/apache2/apache2.conf`):

```apache
# Send logs to Graylog via syslog
ErrorLog "| /usr/bin/logger -t apache -p local6.err"
CustomLog "| /usr/bin/logger -t apache -p local6.info" combined
```

Then configure rsyslog to forward to Graylog (see [System Logs](#system-logs-syslog) section).

---

## 💻 Programming Languages

### Python

#### Using Python Syslog Handler

```python
import logging
import logging.handlers

# Create logger
logger = logging.getLogger('myapp')
logger.setLevel(logging.INFO)

# Add Graylog handler
handler = logging.handlers.SysLogHandler(
    address=('localhost', 1514),
    facility=logging.handlers.SysLogHandler.LOG_USER
)

# Format
formatter = logging.Formatter(
    '%(name)s: [%(levelname)s] %(message)s'
)
handler.setFormatter(formatter)
logger.addHandler(handler)

# Use it
logger.info('Application started')
logger.error('Something went wrong', exc_info=True)
```

#### Using graypy (GELF)

```bash
pip install graypy
```

```python
import logging
import graypy

logger = logging.getLogger('myapp')
logger.setLevel(logging.INFO)

# Add GELF handler
handler = graypy.GELFUDPHandler('localhost', 12201)
logger.addHandler(handler)

# Add custom fields
logger.info('User logged in', extra={
    'user_id': 12345,
    'ip_address': '192.168.1.1',
    'action': 'login'
})
```

### Node.js

#### Using winston-syslog

```bash
npm install winston winston-syslog
```

```javascript
const winston = require('winston');
require('winston-syslog').Syslog;

const logger = winston.createLogger({
  transports: [
    new winston.transports.Syslog({
      host: 'localhost',
      port: 1514,
      protocol: 'udp4',
      app_name: 'nodejs-app'
    })
  ]
});

logger.info('Application started');
logger.error('Error occurred', { userId: 123, action: 'payment' });
```

#### Using gelf-stream (GELF)

```bash
npm install gelf-stream bunyan
```

```javascript
const bunyan = require('bunyan');
const gelfStream = require('gelf-stream');

const logger = bunyan.createLogger({
  name: 'myapp',
  streams: [{
    type: 'raw',
    stream: gelfStream.forBunyan('localhost', 12201)
  }]
});

logger.info({ userId: 123 }, 'User action');
```

### Java / Spring Boot

#### Logback with GELF

Add dependency (`pom.xml`):

```xml
<dependency>
    <groupId>de.siegmar</groupId>
    <artifactId>logback-gelf</artifactId>
    <version>4.0.2</version>
</dependency>
```

Configure (`logback-spring.xml`):

```xml
<configuration>
    <appender name="GELF" class="de.siegmar.logbackgelf.GelfUdpAppender">
        <graylogHost>localhost</graylogHost>
        <graylogPort>12201</graylogPort>
        <layout class="de.siegmar.logbackgelf.GelfLayout">
            <originHost>myapp</originHost>
            <includeRawMessage>false</includeRawMessage>
            <includeMarker>true</includeMarker>
            <includeMdcData>true</includeMdcData>
            <includeCallerData>false</includeCallerData>
            <includeRootCauseData>false</includeRootCauseData>
            <includeLevelName>false</includeLevelName>
            <shortPatternLayout class="ch.qos.logback.classic.PatternLayout">
                <pattern>%m%nopex</pattern>
            </shortPatternLayout>
        </layout>
    </appender>

    <root level="INFO">
        <appender-ref ref="GELF"/>
    </root>
</configuration>
```

### Go

```bash
go get github.com/Graylog2/go-gelf/gelf
```

```go
package main

import (
    "log"
    "github.com/Graylog2/go-gelf/gelf"
)

func main() {
    gelfWriter, err := gelf.NewUDPWriter("localhost:12201")
    if err != nil {
        log.Fatalf("gelf.NewWriter: %s", err)
    }
    defer gelfWriter.Close()

    log.SetOutput(gelfWriter)
    log.Println("Application started")
}
```

---

## 🖥️ System Logs (Syslog)

### rsyslog (Linux)

Edit `/etc/rsyslog.conf` or create `/etc/rsyslog.d/graylog.conf`:

```bash
# Forward all logs to Graylog
*.* @localhost:1514;RSYSLOG_SyslogProtocol23Format

# Or UDP:
# *.* @localhost:1514

# Or only specific facilities:
# local0.* @localhost:1514
# auth,authpriv.* @localhost:1514
```

Restart rsyslog:

```bash
sudo systemctl restart rsyslog
```

### syslog-ng

Edit `/etc/syslog-ng/syslog-ng.conf`:

```
destination d_graylog {
    syslog("localhost" port(1514) transport("udp"));
};

log {
    source(s_src);
    destination(d_graylog);
};
```

Restart:

```bash
sudo systemctl restart syslog-ng
```

---

## ☸️ Kubernetes

### Using Fluentd

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/*.log
      pos_file /var/log/fluentd-containers.log.pos
      tag kubernetes.*
      read_from_head true
      <parse>
        @type json
        time_format %Y-%m-%dT%H:%M:%S.%NZ
      </parse>
    </source>

    <match kubernetes.**>
      @type gelf
      host graylog.logging.svc.cluster.local
      port 12201
      protocol udp
      <buffer>
        flush_interval 5s
      </buffer>
    </match>
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1-debian-gelf
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: config
          mountPath: /fluentd/etc
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: config
        configMap:
          name: fluentd-config
```

### Using Fluent Bit (Lightweight)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
data:
  fluent-bit.conf: |
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*

    [OUTPUT]
        Name              gelf
        Match             *
        Host              graylog.logging.svc.cluster.local
        Port              12201
        Mode              udp
        Gelf_Short_Message_Key log
```

---

## 🛠️ Custom Applications

### Raw TCP/UDP Syslog

```python
import socket

def send_syslog(message, host='localhost', port=1514):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(message.encode('utf-8'), (host, port))
    sock.close()

send_syslog('<14>myapp: This is a test message')
```

### Raw GELF (JSON)

```python
import socket
import json

def send_gelf(message, host='localhost', port=12201):
    gelf_message = {
        "version": "1.1",
        "host": "myhost",
        "short_message": message,
        "level": 1,
        "_custom_field": "custom_value"
    }
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(json.dumps(gelf_message).encode('utf-8'), (host, port))
    sock.close()

send_gelf("Test GELF message")
```

### HTTP API (Advanced)

```bash
curl -X POST http://localhost:9000/gelf \
  -H "Content-Type: application/json" \
  -d '{
    "version": "1.1",
    "host": "api-server",
    "short_message": "API request processed",
    "level": 6,
    "_user_id": 12345,
    "_endpoint": "/api/users",
    "_response_time": 45
  }'
```

---

## 🧪 Testing Your Setup

### Test Syslog

```bash
logger -n localhost -P 1514 "Test message from command line"
```

### Test GELF

```bash
echo '{"version":"1.1","host":"test","short_message":"Test GELF","level":1}' | nc -u localhost 12201
```

### Verify in Graylog

1. Go to **Search**
2. Look for your test messages
3. Check fields and metadata

---

## 📊 Best Practices

### 1. Use Meaningful Tags

```yaml
# Good
tag: "frontend-api-production"
tag: "substrate-validator-tokyo-01"

# Bad
tag: "app"
tag: "container-1"
```

### 2. Add Custom Fields

```yaml
labels:
  environment: "production"
  service: "payment-api"
  region: "us-east-1"
  version: "v1.2.3"
```

### 3. Use Compression for High Volume

```yaml
logging:
  driver: gelf
  options:
    gelf-compression-type: "gzip"
```

### 4. Non-Blocking Mode

Prevents application slowdown if Graylog is unavailable:

```yaml
logging:
  driver: gelf
  options:
    mode: "non-blocking"
    max-buffer-size: "4m"
```

### 5. Filter at Source

Don't send everything if not needed:

```python
# Python example - only send warnings and errors
handler.setLevel(logging.WARNING)
```

---

## 🔍 Troubleshooting

### Logs Not Appearing?

```bash
# 1. Check input is running in Graylog
# System → Inputs - should show green "RUNNING"

# 2. Test connectivity
nc -zvu localhost 12201

# 3. Check Docker logging driver
docker inspect your-container | grep -A 10 LogConfig

# 4. Check Graylog logs
docker compose logs graylog | grep GELF

# 5. Verify network connectivity
docker network inspect logs_graylog
```

### High Latency?

- Enable compression: `gelf-compression-type: "gzip"`
- Use non-blocking mode: `mode: "non-blocking"`
- Increase buffer: `gelf-buffer-size: "16384"`

---

**Next:** See [GRAYLOG_SETUP.md](GRAYLOG_SETUP.md) for managing the Graylog stack itself.

