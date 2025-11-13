# Graylog Docker Compose Setup

Production-ready Infrastructure as Code setup for Graylog with MongoDB and OpenSearch.

## 🎯 Purpose

Centralized log management system for:
- **Substrate/Blockchain nodes** - aggregate logs from multiple nodes
- **Microservices** - centralize logs from distributed applications
- **Production systems** - monitor, debug, and analyze logs in real-time
- **Development** - test log aggregation before production deployment

## 🏗️ Architecture

Three-component stack running in isolated Docker network:

- **MongoDB** - stores Graylog configuration and metadata
- **OpenSearch** - indexes and stores logs
- **Graylog** - log management server with web UI

**Security:** MongoDB and OpenSearch are accessible **only within Docker network**. Only Graylog ports are exposed externally.

## 📚 Documentation

### **[GRAYLOG_SETUP.md](GRAYLOG_SETUP.md)**
Complete guide for setting up and managing the Graylog stack:
- Installation steps
- Input configuration
- Docker Compose commands
- Backup & restore
- Troubleshooting

### **[CLIENT_SETUP.md](CLIENT_SETUP.md)**
Guide for configuring applications to send logs to Graylog:
- Substrate/Blockchain nodes (Docker GELF)
- Docker containers
- Web servers (Nginx, Apache)
- Applications (Python, Node.js, Java, Go)
- Kubernetes, Syslog, custom apps


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
| 12201 | TCP/UDP | GELF (Graylog Extended Log Format) |

## 📄 License

See [LICENSE](LICENSE) file.

## 🔗 Links

- [Graylog Documentation](https://docs.graylog.org/)
- [OpenSearch Documentation](https://opensearch.org/docs/)
- [MongoDB Documentation](https://docs.mongodb.com/)
