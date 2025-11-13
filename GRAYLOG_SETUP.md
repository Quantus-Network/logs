# Graylog Stack Setup Guide

## 🚀 Setup

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd logs
```

### Step 2: Create `.env` File

```bash
cp env.template .env
```

### Step 3: Edit `.env`

Open `.env` and set your passwords:

```bash
# Set admin password (plain text)
GRAYLOG_ROOT_PASSWORD=YourPassword123!

# Generate SHA256 hash of the same password:
# echo -n "YourPassword123!" | sha256sum | cut -d" " -f1
GRAYLOG_ROOT_PASSWORD_SHA2=your-sha256-hash-here

# Set a random string (minimum 16 characters)
GRAYLOG_PASSWORD_SECRET=your-random-secret-here

# Set database passwords
MONGODB_PASSWORD=your-mongodb-password
OPENSEARCH_PASSWORD=your-opensearch-password

# Set Graylog URL
GRAYLOG_HTTP_EXTERNAL_URI=http://your-server.com:9000/
```

**Important:** `GRAYLOG_ROOT_PASSWORD` and `GRAYLOG_ROOT_PASSWORD_SHA2` must match!

### Step 4: Start

```bash
docker compose up -d
```

### Step 5: Verify

```bash
# Check status (wait ~60 seconds for "healthy")
docker compose ps

# Check logs
docker compose logs -f graylog
# Wait for: "Graylog server up and running"
```

Access: **http://localhost:9000**  
Login: `admin` / (password you set)

**Note:** Inputs (GELF, Syslog) are imported automatically! Check **System → Inputs** in UI.

---

## ⚙️ Inputs (Auto-configured)

Docker Compose automatically creates 4 inputs:
- **GELF UDP** on port 12201
- **GELF TCP** on port 12201  
- **Syslog UDP** on port 1514
- **Syslog TCP** on port 1514

All inputs are defined in `graylog-inputs.json` - edit if needed, then restart:

```bash
docker compose down
docker compose up -d
```

### Test Inputs

```bash
# Test Syslog
logger -n localhost -P 1514 "Test message"

# Test GELF
echo '{"version":"1.1","host":"test","short_message":"Test GELF","level":1}' | nc -u localhost 12201
```

Go to **http://localhost:9000** → **Search** to see messages.

---

## 🔧 Docker Compose Commands

```bash
# Start
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
docker compose logs -f graylog

# Stop
docker compose stop

# Restart
docker compose restart

# Remove containers (keeps data in volumes)
docker compose down

# Remove everything including all data
docker compose down -v
```

---

## 💾 Backup

```bash
# Backup MongoDB
docker compose exec mongodb mongodump \
  --uri="mongodb://$(grep MONGODB_USER .env | cut -d'=' -f2):$(grep MONGODB_PASSWORD .env | cut -d'=' -f2)@localhost:27017/graylog?authSource=admin" \
  --archive > backup-$(date +%Y%m%d).archive
```

### Restore

```bash
# Copy backup into container
docker cp ./backup-20241105.archive graylog_mongodb:/tmp/restore.archive

# Restore
docker compose exec mongodb mongorestore \
  --uri="mongodb://$(grep MONGODB_USER .env | cut -d'=' -f2):$(grep MONGODB_PASSWORD .env | cut -d'=' -f2)@localhost:27017/graylog?authSource=admin" \
  --archive=/tmp/restore.archive

# Restart
docker compose restart graylog
```

---

## 🐛 Troubleshooting

### Graylog Won't Start

```bash
# Check logs
docker compose logs graylog | tail -100

# Common issues:
# 1. OpenSearch not ready - wait 1-2 minutes
# 2. Invalid PASSWORD_SECRET - must be 16+ characters
# 3. MongoDB connection failed - check password in .env
```

### Cannot Login

```bash
# Reset password:
echo -n "NewPassword123!" | shasum -a 256 | cut -d" " -f1
# Update GRAYLOG_ROOT_PASSWORD_SHA2 in .env
docker compose restart graylog
```

### OpenSearch Memory Issues (Linux only)

```bash
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

### Logs Not Appearing

1. ✅ Is input running? (green icon in System → Inputs)
2. ✅ Correct port?
3. ✅ Firewall not blocking?
4. ✅ Check: `docker compose logs graylog`

### Change Ports

Edit `.env`:
```bash
GRAYLOG_HTTP_PORT=8080
GRAYLOG_GELF_TCP_PORT=12345
```
Then: `docker compose restart`

---

## 📊 Resource Usage

Default configuration uses:
- **MongoDB:** ~1GB RAM
- **OpenSearch:** ~2GB RAM  
- **Graylog:** ~2GB RAM

**Total:** ~5GB RAM recommended

To reduce OpenSearch memory, edit `.env`:
```bash
OPENSEARCH_HEAP_SIZE=512m  # default is 1g
```

---

**Next:** Configure your applications to send logs - see [CLIENT_SETUP.md](CLIENT_SETUP.md)
