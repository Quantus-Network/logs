# Graylog Stack Setup Guide

Complete guide for installing, configuring, and managing the Graylog logging stack.

## 📋 Table of Contents

- [Quick Installation](#-quick-installation)
- [Manual Installation](#-manual-installation)
- [Configuration](#️-configuration)
- [Management](#-management)
- [Backup & Restore](#-backup--restore)
- [Monitoring](#-monitoring)
- [Troubleshooting](#-troubleshooting)
- [Production Deployment](#-production-deployment)

---

## ⚡ Quick Installation

### Automatic Setup (Recommended)

```bash
# 1. Clone or download this repository
cd /path/to/graylog-docker

# 2. Run setup script
./setup.sh

# The script will:
# - Check Docker installation
# - Create .env file
# - Generate secure passwords
# - Ask for admin password
# - Configure external URL

# 3. Start the stack
docker compose up -d

# 4. Wait ~60 seconds for services to start
docker compose logs -f graylog
# Wait for: "Graylog server up and running"

# 5. Access Graylog
# Open: http://localhost:9000
# Login: admin / (password you set)
```

**Done!** Skip to [First Login](#first-login) section.

---

## 🔧 Manual Installation

### Step 1: Create `.env` File

```bash
cp env.template .env
```

### Step 2: Generate Passwords

#### GRAYLOG_PASSWORD_SECRET (minimum 16 characters)

```bash
openssl rand -base64 96
```

Copy the output and paste into `.env`:
```bash
GRAYLOG_PASSWORD_SECRET=<paste here>
```

#### Admin Password Hash

Choose your admin password and generate SHA256 hash:

**macOS:**
```bash
echo -n "YourPassword123!" | shasum -a 256 | cut -d" " -f1
```

**Linux:**
```bash
echo -n "YourPassword123!" | sha256sum | cut -d" " -f1
```

Copy the hash and paste into `.env`:
```bash
GRAYLOG_ROOT_PASSWORD_SHA2=<paste hash here>
```

#### MongoDB Password

```bash
openssl rand -base64 32
```

Paste into `.env`:
```bash
MONGODB_PASSWORD=<paste here>
```

#### OpenSearch Password

Generate password with special characters:
```bash
openssl rand -base64 16 | head -c 16 && echo "Aa1!"
```

Paste into `.env`:
```bash
OPENSEARCH_PASSWORD=<paste here>
```

### Step 3: Configure External URL

Edit `.env`:
```bash
# For local testing:
GRAYLOG_HTTP_EXTERNAL_URI=http://localhost:9000/

# For server deployment:
GRAYLOG_HTTP_EXTERNAL_URI=http://your-server.com:9000/
# Or with HTTPS:
GRAYLOG_HTTP_EXTERNAL_URI=https://logs.your-domain.com/
```

### Step 4: Start the Stack

```bash
docker compose up -d
```

### Step 5: Verify Installation

```bash
# Check container status
docker compose ps

# All containers should show (healthy) status after ~60 seconds
# If showing (health: starting), wait a bit longer

# Check logs
docker compose logs -f graylog

# Wait for this message:
# "Graylog server up and running"
```

---

## 🎯 First Login

### Access Graylog

1. Open browser: **http://localhost:9000**
2. Login:
   - **Username:** `admin`
   - **Password:** (the password you set, NOT the hash)

### Change Default Password

⚠️ **Important:** Change the default password immediately!

1. Click your username (top right)
2. Go to **Edit Profile**
3. Click **Change Password**
4. Enter current and new password
5. Save

---

## ⚙️ Configuration

### Configure First Input

Inputs tell Graylog how to receive logs.

#### GELF UDP (Recommended for Docker)

1. Go to **System → Inputs**
2. Select **GELF UDP** from dropdown
3. Click **Launch new input**
4. Configure:
   - **Title:** `Docker GELF`
   - **Bind address:** `0.0.0.0`
   - **Port:** `12201`
5. Click **Save**

#### Syslog UDP (For System Logs)

1. Go to **System → Inputs**
2. Select **Syslog UDP** from dropdown
3. Click **Launch new input**
4. Configure:
   - **Title:** `Syslog UDP`
   - **Bind address:** `0.0.0.0`
   - **Port:** `1514`
5. Click **Save**

### Test Input

```bash
# Test Syslog
logger -n localhost -P 1514 "Test message from syslog"

# Test GELF
echo '{"version":"1.1","host":"test","short_message":"Test GELF","level":1}' | nc -u localhost 12201
```

Go to **Search** in Graylog - you should see your test messages!

---

## 🔧 Management

### Using Makefile

```bash
# Show all available commands
make help

# Setup (create .env)
make setup

# Start services
make start

# Stop services
make stop

# Restart services
make restart

# View all logs
make logs

# View specific service logs
make logs-graylog
make logs-mongodb
make logs-opensearch

# Check status and health
make status
make health

# Monitor in real-time
make monitor

# Backup MongoDB
make backup

# Update Docker images
make update

# Clean (remove containers, keep data)
make clean

# Clean everything (removes data!)
make clean-all
```

### Using Docker Compose Directly

```bash
# Start
docker compose up -d

# Stop
docker compose stop

# Restart
docker compose restart

# Logs
docker compose logs -f
docker compose logs -f graylog

# Status
docker compose ps

# Remove containers (keeps data)
docker compose down

# Remove everything including data
docker compose down -v
```

### Updating Configuration

After changing `.env`:

```bash
# Restart affected services
docker compose restart

# Or restart specific service
docker compose restart graylog
```

---

## 💾 Backup & Restore

### Automatic Backup

```bash
# Run backup (saves to ./backups/ directory)
make backup

# Or manually:
docker compose exec mongodb mongodump \
  --uri="mongodb://$(grep MONGODB_USER .env | cut -d'=' -f2):$(grep MONGODB_PASSWORD .env | cut -d'=' -f2)@localhost:27017/graylog?authSource=admin" \
  --archive > backups/mongodb-backup-$(date +%Y%m%d-%H%M%S).archive
```

### Schedule Regular Backups

Add to crontab:

```bash
# Daily backup at 2 AM
0 2 * * * cd /path/to/graylog && make backup > /dev/null 2>&1

# Weekly backup on Sunday at 3 AM
0 3 * * 0 cd /path/to/graylog && make backup > /dev/null 2>&1
```

### Restore from Backup

```bash
# Copy backup into container
docker cp ./backups/mongodb-backup-20241105.archive graylog_mongodb:/tmp/restore.archive

# Restore
docker compose exec mongodb mongorestore \
  --uri="mongodb://$(grep MONGODB_USER .env | cut -d'=' -f2):$(grep MONGODB_PASSWORD .env | cut -d'=' -f2)@localhost:27017/graylog?authSource=admin" \
  --archive=/tmp/restore.archive

# Restart Graylog
docker compose restart graylog
```

---

## 📊 Monitoring

### Built-in Monitoring Script

```bash
# Run monitor (shows status, health, resources)
./monitor.sh

# Or using make:
make monitor
```

### Check Health Status

```bash
# View container health
docker compose ps

# All services should show (healthy) status
```

### Resource Usage

```bash
# View real-time resource usage
docker stats $(docker compose ps -q)

# Or using make:
make status
```

### Graylog Metrics

Access metrics endpoint:
```bash
curl http://localhost:9000/api/system/metrics/namespace/jvm.memory
```

---

## 🐛 Troubleshooting

### Graylog Won't Start

**Symptom:** Container keeps restarting or shows unhealthy

**Solutions:**

```bash
# 1. Check logs
docker compose logs graylog | tail -100

# 2. Common issues:

# a) OpenSearch not ready yet - wait 1-2 minutes
docker compose logs opensearch

# b) Invalid PASSWORD_SECRET
# Must be at least 16 characters
# Regenerate: openssl rand -base64 96

# c) MongoDB connection failed
# Check MongoDB is running and password is correct
docker compose logs mongodb
```

### Cannot Login

**Symptom:** Invalid credentials

**Solutions:**

```bash
# 1. Verify you're using the PASSWORD, not the hash

# 2. Reset admin password:
echo -n "NewPassword123!" | shasum -a 256 | cut -d" " -f1

# 3. Update GRAYLOG_ROOT_PASSWORD_SHA2 in .env with the hash

# 4. Restart
docker compose restart graylog
```

### OpenSearch Memory Issues

**Symptom:** OpenSearch container crashes or shows memory errors

**Solution for Linux:**

```bash
# Increase vm.max_map_count
sudo sysctl -w vm.max_map_count=262144

# Make permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

**Solution for macOS:**
This is usually already configured correctly in Docker Desktop.

### Logs Not Appearing

**Checklist:**

1. ✅ Is input running? (green icon in System → Inputs)
2. ✅ Correct port in your application?
3. ✅ Firewall not blocking?
4. ✅ Check System → Nodes - is node active?
5. ✅ Check logs: `docker compose logs graylog`

### High CPU/RAM Usage

**OpenSearch:**

```bash
# Reduce heap size in .env:
OPENSEARCH_HEAP_SIZE=512m  # default is 1g
```

**Graylog:**
Resource limits are already configured in docker-compose.yml.
To adjust, edit the `deploy.resources` section.

### Port Already in Use

**Symptom:** Cannot start - port 9000/1514/12201 already in use

**Solution:**

```bash
# Option 1: Stop conflicting service
lsof -ti:9000 | xargs kill -9

# Option 2: Change port in .env
GRAYLOG_HTTP_PORT=9001
# Then restart: docker compose restart
```

---

## 🚀 Production Deployment

### Prerequisites

- Server with minimum 8GB RAM
- 20GB+ disk space
- Static IP or domain name
- Firewall configured

### Production Checklist

#### 1. Change All Default Passwords

```bash
# Generate strong passwords
openssl rand -base64 32

# Update .env:
MONGODB_PASSWORD=<strong-password>
OPENSEARCH_PASSWORD=<Strong-Password-123!>
# And admin password hash
```

#### 2. Configure Proper External URL

```bash
# In .env:
GRAYLOG_HTTP_EXTERNAL_URI=https://logs.yourdomain.com/
```

#### 3. Setup HTTPS with Reverse Proxy

**nginx example:**

```nginx
server {
    listen 443 ssl http2;
    server_name logs.yourdomain.com;

    ssl_certificate /etc/ssl/certs/your-cert.pem;
    ssl_certificate_key /etc/ssl/private/your-key.pem;

    location / {
        proxy_pass http://localhost:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Graylog-Server-URL https://logs.yourdomain.com/;
    }
}
```

#### 4. Configure Firewall

```bash
# Allow only necessary ports
ufw allow 443/tcp   # HTTPS (through nginx)
ufw allow 1514/tcp  # Syslog TCP
ufw allow 1514/udp  # Syslog UDP
ufw allow 12201/tcp # GELF TCP
ufw allow 12201/udp # GELF UDP

# Do NOT expose:
# - Port 9000 (only through reverse proxy)
# - Port 27017 (MongoDB)
# - Port 9200 (OpenSearch)
```

#### 5. Setup Backup Automation

```bash
# Add to crontab:
crontab -e

# Daily backup at 2 AM
0 2 * * * cd /path/to/graylog && /usr/local/bin/docker compose exec -T mongodb mongodump --uri="mongodb://user:pass@localhost:27017/graylog?authSource=admin" --archive > /backups/graylog-$(date +\%Y\%m\%d).archive

# Keep only last 7 days
0 3 * * * find /backups -name "graylog-*.archive" -mtime +7 -delete
```

#### 6. Setup Monitoring

Monitor the stack itself:
- Container health: `docker compose ps`
- Resource usage: `docker stats`
- Graylog metrics: Available at `/api/system/metrics`

#### 7. Configure Log Rotation in Graylog

1. Go to **System → Indices**
2. Edit Default Index Set
3. Configure:
   - **Rotation Strategy:** Index Size (e.g., 1GB) or Index Time (e.g., 1 day)
   - **Retention Strategy:** Delete (e.g., keep 10 indices)
4. Save

This prevents unlimited log growth.

#### 8. Test Disaster Recovery

```bash
# 1. Make backup
make backup

# 2. Destroy everything
docker compose down -v

# 3. Restore from backup
docker compose up -d
# Wait for services to start
# Then restore backup (see Backup & Restore section)

# 4. Verify data is intact
```

---

## 📈 Performance Tuning

### For High Log Volume

Edit `.env`:

```bash
# Increase OpenSearch heap
OPENSEARCH_HEAP_SIZE=4g

# Consider adjusting Graylog buffers in docker-compose.yml:
# - GRAYLOG_PROCESSBUFFER_PROCESSORS=10
# - GRAYLOG_OUTPUTBUFFER_PROCESSORS=5
# - GRAYLOG_OUTPUT_BATCH_SIZE=1000
```

### For Low Resources

```bash
# Reduce OpenSearch heap
OPENSEARCH_HEAP_SIZE=512m

# Adjust resource limits in docker-compose.yml
```

---

## 🔗 Integration with Monitoring

### Prometheus + Grafana

If you already have Prometheus/Grafana:

**Graylog for:** Log analysis, debugging, error tracking
**Prometheus/Grafana for:** Metrics, dashboards, performance monitoring

They complement each other:
- Prometheus alert: "Error rate increased to 5%"
- You check Graylog: See actual error messages and stack traces

### Export Metrics to Prometheus

Graylog exposes metrics at:
```
http://localhost:9000/api/cluster/metrics/multiple
```

Configure Prometheus to scrape these metrics.

---

## 📞 Support

- **Documentation:** See [CLIENT_SETUP.md](CLIENT_SETUP.md) for configuring apps to send logs
- **Community:** [Graylog Community Forums](https://community.graylog.org/)
- **Issues:** Open GitHub issue

---

**Next:** Configure your applications to send logs - see [CLIENT_SETUP.md](CLIENT_SETUP.md)

