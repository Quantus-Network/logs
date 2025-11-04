# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-04

### Added
- Basic Docker Compose configuration for Graylog
- MongoDB as metadata backend
- OpenSearch as log storage
- Network isolation - MongoDB and OpenSearch accessible only within stack
- `.env` file for all passwords and configuration
- `env.template` template with example values
- Automatic `setup.sh` script for environment initialization
- Makefile with commands for stack management
- Comprehensive documentation:
  - `README.md` - main documentation
  - `QUICKSTART.md` - quick start (2 minutes)
  - `SETUP_GUIDE.md` - detailed configuration guide
- Example files:
  - `docker-compose.override.yml.example` - for development
  - `docker-compose.prod.yml` - production configuration with healthchecks
- Port configuration:
  - 9000 - Graylog Web UI
  - 1514 - Syslog TCP/UDP
  - 12201 - GELF TCP/UDP
- Docker volumes for data persistence
- `.gitignore` and `.dockerignore`
- Timezone integration (default Europe/Warsaw)
- Optional email configuration (SMTP)

### Security
- All passwords in `.env`
- Automatic generation of strong passwords
- No external exposure of MongoDB (27017) and OpenSearch (9200) ports
- Isolated Docker network for inter-service communication
- Administrator password as SHA2 hash

### Tools
- Automatic MongoDB backup (`make backup`)
- Health checks for all services
- Per-service logs (`make logs-graylog`, `make logs-mongodb`, etc.)
- Resource limits in production version
- Shell access to containers

### Documentation
- Installation instructions (automatic and manual)
- Input configuration (Syslog, GELF)
- Integration examples (Docker, Nginx, Python, Node.js)
- Troubleshooting
- Production best practices
- Backup/restore guide
- Alert and email notification configuration

## [Unreleased]

### Planned
- Content packs with predefined dashboards
- Configuration examples for popular applications
- Automatic backup scripts (cron)
- Grafana integration example
- Prometheus exporter for metrics
- Ansible playbook for deployment
- Terraform configuration
- Kubernetes/Helm charts
- Multi-node cluster setup
- GeoIP integration example

---

## Types of Changes

- **Added** - new features
- **Changed** - changes to existing features
- **Deprecated** - features to be removed in future versions
- **Removed** - removed features
- **Fixed** - bug fixes
- **Security** - security-related changes
