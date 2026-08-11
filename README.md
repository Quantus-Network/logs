# Graylog Docker Compose Setup

Production-ready Infrastructure as Code setup for Graylog with MongoDB and OpenSearch.

**Built specifically for Quantus Network validator nodes.**

## 🎯 Purpose

Centralized log management system for **Quantus Network**:
- **Validator nodes** - aggregate logs from multiple validators across servers
- **Production monitoring** - real-time monitoring and debugging
- **Performance analysis** - track block production, finalization, and network health
- **Alert system** - get notified about critical errors and consensus issues

## 🏗️ Architecture

Three-component stack running in isolated Docker network:

- **MongoDB** - stores Graylog configuration and metadata
- **OpenSearch** - indexes and stores logs
- **Graylog** - log management server with web UI

**Security:** MongoDB and OpenSearch are accessible **only within Docker network**. GELF UDP is bound to localhost + Tailscale IP only (set `GRAYLOG_GELF_BIND_TAILSCALE` in `.env`).

## 📚 Documentation

### **[GRAYLOG_SETUP.md](GRAYLOG_SETUP.md)**
Complete guide for setting up and managing the Graylog stack:
- Installation steps
- Input configuration
- Docker Compose commands
- Backup & restore
- Troubleshooting

### **[CLIENT_SETUP.md](CLIENT_SETUP.md)**
Guide for configuring Quantus Network nodes to send logs to Graylog:
- Basic setup (just add logging to docker-compose)
- Advanced configuration (labels, compression, non-blocking)
- Multiple nodes setup
- Useful Graylog searches for Substrate
- Troubleshooting guide


## 🚀 Quick Start

```bash
git clone <repository-url>
cd logs
cp env.template .env    # Edit and set passwords
docker compose up -d    # Auto-imports inputs!
```

Access: **http://localhost:9000** (login: `admin`)

Inputs (GELF, Syslog) are configured automatically. See [GRAYLOG_SETUP.md](GRAYLOG_SETUP.md) for details.

## 📊 Ports

| Port | Protocol | Service |
|------|----------|---------|
| 9000 | HTTP | Graylog Web UI & API |
| 1514 | TCP/UDP | Syslog |
| 12201 | UDP | GELF — bound to `127.0.0.1` + `GRAYLOG_GELF_BIND_TAILSCALE` only |

## 📄 License

See [LICENSE](LICENSE) file.

## 🔗 Links

- [Graylog Documentation](https://docs.graylog.org/)
- [OpenSearch Documentation](https://opensearch.org/docs/)
- [MongoDB Documentation](https://docs.mongodb.com/)
