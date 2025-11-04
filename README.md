# Graylog Docker Compose Setup

Infrastructure as Code setup for Graylog with MongoDB and OpenSearch.

> 🚀 **Want to get started quickly?** See [QUICKSTART.md](QUICKSTART.md) - 2 minutes to running Graylog!

## 🏗️ Architecture

- **MongoDB** - stores Graylog configuration and metadata
- **OpenSearch** - stores logs and data
- **Graylog** - log management server

### 🔒 Security

- All passwords are stored in `.env` file
- MongoDB and OpenSearch are accessible **only within Docker network** (zero external visibility)
- Only Graylog is exposed externally through selected ports

## 📋 Requirements

- Docker Engine 20.10+
- Docker Compose 2.0+
- Minimum 4GB RAM (8GB recommended)
- Minimum 10GB disk space

## 🚀 Quick Start

### Method 1: Automatic (RECOMMENDED)

```bash
# Run setup script
./setup.sh

# Start the stack
make start

# Check status
make status
```

Done! Open http://localhost:9000 and login as `admin`.

### Method 2: Manual

### 1. Environment Preparation

Copy the template to `.env`:

```bash
cp env.template .env
```

### 2. Generate Passwords and Secrets

#### Password Secret (minimum 16 characters)

**macOS/Linux:**
```bash
openssl rand -base64 96
```

Or if you have `pwgen`:
```bash
pwgen -N 1 -s 96
```

Paste the result into `.env` as `GRAYLOG_PASSWORD_SECRET`

#### Root Password SHA2

Choose a password for the administrator and generate the hash:

**macOS:**
```bash
echo -n "YourPassword123!" | shasum -a 256 | cut -d" " -f1
```

**Linux:**
```bash
echo -n "YourPassword123!" | sha256sum | cut -d" " -f1
```

Paste the result into `.env` as `GRAYLOG_ROOT_PASSWORD_SHA2`

#### Other Passwords

Also change:
- `MONGODB_PASSWORD` - MongoDB password
- `OPENSEARCH_PASSWORD` - OpenSearch password (min. 8 characters, upper/lower case, numbers, special characters)

### 3. URL Configuration

Change `GRAYLOG_HTTP_EXTERNAL_URI` in the `.env` file to the address where Graylog will be accessible:

- Locally: `http://localhost:9000/`
- Server: `http://your-server.com:9000/`

### 4. Starting Up

```bash
docker-compose up -d
```

### 5. Check Status

```bash
docker-compose ps
docker-compose logs -f graylog
```

### 6. Access Graylog

Open your browser and navigate to:
```
http://localhost:9000
```

Login using:
- **Username:** value from `GRAYLOG_ROOT_USERNAME` (default: `admin`)
- **Password:** the password you used to generate `GRAYLOG_ROOT_PASSWORD_SHA2`

## 📊 Ports

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Graylog Web UI | 9000 | HTTP | Web interface |
| Syslog | 1514 | TCP/UDP | Receiving Syslog logs |
| GELF | 12201 | TCP/UDP | Graylog Extended Log Format |

## 🔧 Management

### Stop Services

```bash
docker-compose stop
```

### Restart Services

```bash
docker-compose restart
```

### Shutdown and Remove Containers

```bash
docker-compose down
```

### Shutdown with Data Removal

⚠️ **WARNING:** This will remove all collected logs!

```bash
docker-compose down -v
```

### Logs

```bash
# All services
docker-compose logs -f

# Graylog only
docker-compose logs -f graylog

# MongoDB only
docker-compose logs -f mongodb

# OpenSearch only
docker-compose logs -f opensearch
```

## 📝 Input Configuration

After logging into Graylog:

1. Go to **System → Inputs**
2. Select input type (e.g. Syslog UDP, GELF UDP)
3. Click **Launch new input**
4. Configure the input (port should match ports in docker-compose.yml)
5. Click **Save**

## 🔐 Change Administrator Password

1. Login to Graylog
2. Go to **System → Users**
3. Click on the `admin` user
4. Set new password in the interface

Or update the hash in `.env` and restart:

```bash
echo -n "NewPassword" | shasum -a 256 | cut -d" " -f1
# Paste result into .env as GRAYLOG_ROOT_PASSWORD_SHA2
docker-compose restart graylog
```

## ⚙️ Advanced Configuration

### Increase Memory for OpenSearch

Edit in `.env`:
```bash
OPENSEARCH_HEAP_SIZE=2g  # for larger installations
```

### Email Configuration

Set in `.env`:
```bash
GRAYLOG_EMAIL_ENABLED=true
GRAYLOG_EMAIL_HOSTNAME=smtp.gmail.com
GRAYLOG_EMAIL_PORT=587
GRAYLOG_EMAIL_USE_AUTH=true
GRAYLOG_EMAIL_USERNAME=your-email@gmail.com
GRAYLOG_EMAIL_PASSWORD=your-app-password
GRAYLOG_EMAIL_USE_TLS=true
GRAYLOG_EMAIL_FROM=graylog@yourdomain.com
```

## 🐛 Troubleshooting

### Graylog Cannot Connect to MongoDB

Check logs:
```bash
docker-compose logs mongodb
docker-compose logs graylog
```

Ensure MongoDB is fully started before Graylog.

### OpenSearch Has Memory Issues

Increase `vm.max_map_count` on the host:

**macOS/Docker Desktop:** 
```bash
# This is usually already set correctly
```

**Linux:**
```bash
sudo sysctl -w vm.max_map_count=262144
# To make it persistent:
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

### Cannot Login

1. Check if you used the correct password (the same one you used to generate SHA2)
2. Ensure `GRAYLOG_ROOT_PASSWORD_SHA2` is correctly generated
3. Check logs: `docker-compose logs -f graylog`

## 📚 Documentation

- [Graylog Documentation](https://docs.graylog.org/)
- [OpenSearch Documentation](https://opensearch.org/docs/)
- [MongoDB Documentation](https://docs.mongodb.com/)

## 🔄 Backup and Restore

### Backup

```bash
# MongoDB backup
docker-compose exec mongodb mongodump --uri="mongodb://graylog:password@localhost:27017/graylog?authSource=admin" --out=/dump
docker cp graylog_mongodb:/dump ./backup/mongodb-$(date +%Y%m%d)

# Graylog data
docker-compose exec graylog tar czf /tmp/graylog-data.tar.gz /usr/share/graylog/data
docker cp graylog_server:/tmp/graylog-data.tar.gz ./backup/graylog-data-$(date +%Y%m%d).tar.gz
```

### Restore

```bash
# MongoDB restore
docker cp ./backup/mongodb-20231104 graylog_mongodb:/dump
docker-compose exec mongodb mongorestore --uri="mongodb://graylog:password@localhost:27017/graylog?authSource=admin" /dump
```

## 📖 Detailed Documentation

More information can be found in:
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Complete configuration guide
  - Input configuration
  - Creating dashboards
  - Application integrations (Docker, Nginx, Python, Node.js)
  - Alerting and email notifications
  - Backup and restore
  - Troubleshooting

## 📄 License

See [LICENSE](LICENSE) file
