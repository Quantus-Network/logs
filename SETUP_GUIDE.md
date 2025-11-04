# Graylog - Configuration Guide

## 🚀 Quick Installation (automatic)

### Step 1: Run setup script

```bash
./setup.sh
```

The script automatically:
- Checks if Docker is installed
- Creates `.env` file from template
- Generates secure passwords for MongoDB and OpenSearch
- Generates `GRAYLOG_PASSWORD_SECRET`
- Asks for administrator password and creates SHA2 hash
- Asks for external URL

### Step 2: Start the stack

```bash
make start
# or
docker-compose up -d
```

### Step 3: Check status

```bash
make status
# or
docker-compose ps
```

### Step 4: Login

Open browser: http://localhost:9000

- **Username:** `admin`
- **Password:** password you entered during setup

---

## 🔧 Manual Installation

### Step 1: Prepare .env file

```bash
cp env.template .env
```

### Step 2: Generate GRAYLOG_PASSWORD_SECRET

```bash
openssl rand -base64 96
```

Paste result into `.env` as `GRAYLOG_PASSWORD_SECRET`

### Step 3: Generate administrator password

Choose your password and generate hash:

```bash
echo -n "YourPassword123!" | shasum -a 256 | cut -d" " -f1
```

Paste result into `.env` as `GRAYLOG_ROOT_PASSWORD_SHA2`

### Step 4: Change other passwords

In `.env` file change:
- `MONGODB_PASSWORD`
- `OPENSEARCH_PASSWORD` (min. 8 characters, upper/lower case, numbers, special characters)

### Step 5: URL Configuration

In `.env` set `GRAYLOG_HTTP_EXTERNAL_URI` to the address where Graylog will be accessible:
```
GRAYLOG_HTTP_EXTERNAL_URI=http://localhost:9000/
```

### Step 6: Start

```bash
docker-compose up -d
```

---

## 📊 Input Configuration

After logging into Graylog, configure inputs to receive logs.

### Syslog UDP (simplest)

1. Go to **System → Inputs**
2. Select **Syslog UDP** from list
3. Click **Launch new input**
4. Fill in:
   - **Title:** `Syslog UDP`
   - **Bind address:** `0.0.0.0`
   - **Port:** `1514`
5. Click **Save**

### GELF UDP (recommended for applications)

1. Go to **System → Inputs**
2. Select **GELF UDP** from list
3. Click **Launch new input**
4. Fill in:
   - **Title:** `GELF UDP`
   - **Bind address:** `0.0.0.0`
   - **Port:** `12201`
5. Click **Save**

### Testing input

**Syslog:**
```bash
logger -n localhost -P 1514 "Test message from syslog"
```

**GELF (using netcat):**
```bash
echo '{"version":"1.1","host":"test","short_message":"Test GELF message","level":1}' | nc -u -w1 localhost 12201
```

---

## 🔍 Search and Dashboards

### Basic Search

After receiving logs, go to **Search** and use queries:

```
# All logs
*

# Logs from last hour
*

# Logs containing "error"
message:"error"

# Logs from specific host
source:"hostname"

# Logs with specific level
level:3

# Combination
source:"web-server" AND message:"error"
```

### Creating Dashboards

1. Go to **Dashboards**
2. Click **Create dashboard**
3. Give it a name (e.g. "System Overview")
4. Add widgets:
   - **Quick Values** - most frequent field values
   - **Field Chart** - chart of values over time
   - **Statistics** - numeric statistics
   - **World Map** - geographic map (if you have GeoIP data)

---

## 🎯 Sample Configurations for Different Applications

### Docker Logs (GELF driver)

In your `docker-compose.yml` add to your application:

```yaml
services:
  your-app:
    image: your-image
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
        tag: "your-app"
```

### Nginx Access Logs

Add to Nginx configuration:

```nginx
access_log syslog:server=localhost:1514,facility=local7,tag=nginx,severity=info;
error_log syslog:server=localhost:1514,facility=local7,tag=nginx,severity=error;
```

### Python Logging

```python
import logging
import logging.handlers

logger = logging.getLogger()
handler = logging.handlers.SysLogHandler(address=('localhost', 1514))
logger.addHandler(handler)
logger.setLevel(logging.INFO)

logger.info("Test message from Python")
```

### Node.js / Winston

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

logger.info('Test message from Node.js');
```

---

## ⚙️ Management Using Makefile

```bash
# Help
make help

# Initialize
make setup

# Start
make start

# Stop
make stop

# Restart
make restart

# Logs
make logs
make logs-graylog
make logs-mongodb
make logs-opensearch

# Status
make status

# Health check
make health

# Backup
make backup

# Update
make update

# Shell in container
make shell-graylog
make shell-mongodb
make shell-opensearch

# Clean (preserves data)
make clean

# Clean everything (REMOVES DATA!)
make clean-all
```

---

## 🔐 User Management

### Creating New User

1. Login as `admin`
2. Go to **System → Authentication → Users**
3. Click **Create User**
4. Fill in form:
   - **Username**
   - **Email**
   - **First Name / Last Name**
   - **Password**
   - **Role** (e.g. Reader, Editor, Admin)
5. Click **Create**

### Roles

- **Reader** - read only
- **Editor** - read + create dashboards and streams
- **Admin** - full access

---

## 📧 Email Notification Configuration

### Step 1: Configure SMTP

In `.env` file:

```bash
GRAYLOG_EMAIL_ENABLED=true
GRAYLOG_EMAIL_HOSTNAME=smtp.gmail.com
GRAYLOG_EMAIL_PORT=587
GRAYLOG_EMAIL_USE_AUTH=true
GRAYLOG_EMAIL_USERNAME=your-email@gmail.com
GRAYLOG_EMAIL_PASSWORD=app-password
GRAYLOG_EMAIL_USE_TLS=true
GRAYLOG_EMAIL_USE_SSL=false
GRAYLOG_EMAIL_FROM=graylog@yourdomain.com
```

### Step 2: Restart Graylog

```bash
make restart
```

### Step 3: Test email

In Graylog:
1. Go to **System → Configurations**
2. Click **Update configuration** in Email section
3. Click **Send test email**

### Step 4: Create alerts

1. Go to **Alerts → Event Definitions**
2. Click **Create Event Definition**
3. Configure condition (e.g. log count > 100)
4. Set threshold (e.g. "more than 10 in 5 minutes")
5. Add **Notification** type **Email**
6. Provide recipients
7. Save

---

## 🔄 Backup and Restore

### Automatic backup (MongoDB)

```bash
make backup
```

Backup will be saved in `./backups/`

### Manual backup everything

```bash
# MongoDB
docker-compose exec mongodb mongodump \
  --uri="mongodb://graylog:PASSWORD@localhost:27017/graylog?authSource=admin" \
  --out=/dump

docker cp graylog_mongodb:/dump ./backup/mongodb-$(date +%Y%m%d)

# Graylog data
docker-compose exec graylog tar czf /tmp/graylog-data.tar.gz /usr/share/graylog/data
docker cp graylog_server:/tmp/graylog-data.tar.gz ./backup/graylog-data-$(date +%Y%m%d).tar.gz
```

### Restore

```bash
# MongoDB
docker cp ./backup/mongodb-20231104 graylog_mongodb:/dump
docker-compose exec mongodb mongorestore \
  --uri="mongodb://graylog:PASSWORD@localhost:27017/graylog?authSource=admin" \
  /dump
```

---

## 🐛 Troubleshooting

### Graylog cannot start

**Problem:** `Graylog server NOT running`

**Solution:**
```bash
# Check logs
make logs-graylog

# Most common causes:
# 1. OpenSearch not ready yet - wait 1-2 minutes
# 2. Invalid PASSWORD_SECRET - must be min. 16 characters
# 3. MongoDB issues - check make logs-mongodb
```

### OpenSearch has memory issues

**Problem:** `max virtual memory areas vm.max_map_count [65530] is too low`

**Solution Linux:**
```bash
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

**macOS/Docker Desktop:**
This is usually already set correctly in Docker Desktop.

### Cannot login

**Problem:** Invalid credentials

**Solution:**
```bash
# Reset password
echo -n "NewPassword123!" | shasum -a 256 | cut -d" " -f1
# Paste result into .env as GRAYLOG_ROOT_PASSWORD_SHA2

# Restart Graylog
make restart
```

### Logs not appearing in Graylog

**Checklist:**
1. ✓ Is input running (green icon in System → Inputs)?
2. ✓ Does firewall allow traffic on ports 1514, 12201?
3. ✓ Correct address and port in application sending logs?
4. ✓ Check logs: `make logs-graylog`
5. ✓ Check System → Nodes - is node active?

### High CPU/RAM usage

**OpenSearch:**
```bash
# In .env increase or decrease heap
OPENSEARCH_HEAP_SIZE=2g  # default 1g
```

**Graylog:**
```bash
# In docker-compose.yml add limits
services:
  graylog:
    deploy:
      resources:
        limits:
          memory: 2G
```

---

## 📚 Useful Links

- [Graylog Documentation](https://docs.graylog.org/)
- [Graylog Marketplace](https://marketplace.graylog.org/) - plugins and integrations
- [Graylog Community](https://community.graylog.org/)
- [OpenSearch Documentation](https://opensearch.org/docs/)
- [MongoDB Documentation](https://docs.mongodb.com/)

---

## 💡 Best Practices

1. **Regular backups** - set up cron job for `make backup`
2. **Monitor disk space** - logs can grow quickly
3. **Rotation** - configure Index Rotation in Graylog
4. **Retention** - delete old logs (Data Retention in Graylog)
5. **Security** - don't expose MongoDB and OpenSearch externally
6. **HTTPS** - use reverse proxy (nginx/traefik) with SSL
7. **Strong passwords** - always use strong passwords in production
8. **Updates** - regularly update Docker images

---

## 🔒 Production Security

### Reverse Proxy with SSL (nginx)

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
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Change in `.env`:
```bash
GRAYLOG_HTTP_EXTERNAL_URI=https://logs.yourdomain.com/
```

### Firewall

```bash
# Allow only necessary ports
ufw allow 9000/tcp   # Graylog Web UI (or only through reverse proxy)
ufw allow 1514/tcp   # Syslog TCP
ufw allow 1514/udp   # Syslog UDP
ufw allow 12201/tcp  # GELF TCP
ufw allow 12201/udp  # GELF UDP
```

---

Have questions? Check [documentation](README.md) or open an issue on GitHub!
