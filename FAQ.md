# FAQ - Frequently Asked Questions

## Installation and Setup

### Q: How long does the first start take?

**A:** First start usually takes 1-2 minutes:
- MongoDB: ~10 seconds
- OpenSearch: ~30-60 seconds (indexing and initialization)
- Graylog: ~30-60 seconds (waiting for OpenSearch)

Check progress: `make logs-graylog`

---

### Q: Can I change the ports?

**A:** Yes! In `.env` file change:
```bash
GRAYLOG_HTTP_PORT=8080        # Change from 9000 to 8080
GRAYLOG_SYSLOG_TCP_PORT=514   # Requires sudo on Linux
GRAYLOG_GELF_TCP_PORT=12345   # Any free port
```

Restart: `make restart`

---

### Q: How do I reset the administrator password?

**A:**
```bash
# 1. Generate new hash
echo -n "NewPassword123!" | shasum -a 256 | cut -d" " -f1

# 2. Paste result into .env as GRAYLOG_ROOT_PASSWORD_SHA2

# 3. Restart
make restart
```

---

### Q: Where is data stored?

**A:** In Docker volumes:
- `mongodb_data` - Graylog configuration
- `opensearch_data` - logs
- `graylog_data` - cache and temporary files

Location: 
- Linux: `/var/lib/docker/volumes/`
- macOS: `~/Library/Containers/com.docker.docker/Data/`

---

## Usage

### Q: How do I send logs to Graylog?

**A:** First add an Input (System → Inputs), then:

**Syslog:**
```bash
logger -n localhost -P 1514 "Test message"
```

**GELF via netcat:**
```bash
echo '{"version":"1.1","host":"test","short_message":"Test","level":1}' | nc -u localhost 12201
```

**From Docker:**
```yaml
services:
  app:
    logging:
      driver: gelf
      options:
        gelf-address: "udp://localhost:12201"
```

---

### Q: Logs not appearing in Graylog - what to do?

**A:** Checklist:
1. ✓ Is Input running (green icon)?
2. ✓ Are you sending to correct port?
3. ✓ Is firewall not blocking?
4. ✓ Check `System → Nodes` - is node active?
5. ✓ View logs: `make logs-graylog`

---

### Q: How do I create a Dashboard?

**A:**
1. Go to **Dashboards**
2. Click **Create dashboard**
3. Give it a name
4. Click **Add widget**
5. Choose type (Quick Values, Chart, etc.)
6. Configure and save

---

### Q: How do I set up alerts?

**A:**
1. **Alerts → Event Definitions**
2. **Create Event Definition**
3. Set condition (e.g. `error AND level:3`)
4. Set threshold (e.g. "more than 10 in 5 minutes")
5. Add **Notification** (Email, HTTP, etc.)
6. Save

You need configured SMTP for email!

---

## Performance

### Q: Graylog uses too much RAM/CPU - what to do?

**A:** 

**OpenSearch - decrease heap:**
```bash
# In .env
OPENSEARCH_HEAP_SIZE=512m  # default 1g
```

**Graylog - add limits in docker-compose.yml:**
```yaml
services:
  graylog:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2'
```

---

### Q: How fast do logs grow? How to control space?

**A:** 

**Index Rotation** - in Graylog:
1. **System → Indices**
2. Edit Index Set
3. Set **Rotation Strategy**: "Index Size" (e.g. 1GB) or "Index Time" (e.g. 1 day)
4. Set **Retention**: how many indices to keep (e.g. 10)

This will automatically delete old logs.

---

### Q: Can I scale Graylog horizontally?

**A:** Yes, but it requires:
- Shared MongoDB (one for all nodes)
- Shared/distributed OpenSearch cluster
- Load balancer in front of Graylog nodes
- `GRAYLOG_IS_MASTER=true` configuration on only one node

This is a topic for a separate tutorial - not covered in this setup.

---

## Security

### Q: Are MongoDB and OpenSearch secure?

**A:** In this setup:
- ✅ MongoDB and OpenSearch are **only in Docker network**
- ✅ No exposed ports 27017 and 9200
- ✅ Passwords are in `.env` (never commit!)
- ⚠️ Graylog HTTP (9000) is exposed - use HTTPS in prod!

---

### Q: How do I add HTTPS?

**A:** Use reverse proxy (nginx, traefik, caddy):

**nginx example:**
```nginx
server {
    listen 443 ssl;
    server_name logs.example.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

Change in `.env`:
```bash
GRAYLOG_HTTP_EXTERNAL_URI=https://logs.example.com/
```

---

### Q: How do I add a new user?

**A:**
1. Login as admin
2. **System → Authentication → Users**
3. **Create User**
4. Choose Role:
   - **Reader** - read only
   - **Editor** - read + create dashboards
   - **Admin** - full access

---

## Backup & Recovery

### Q: How often should I backup?

**A:** Recommendations:
- **Daily** - MongoDB (configuration)
- **Weekly** - full snapshot (if you need log history)
- **Before update** - always!

```bash
# Automatic MongoDB backup
make backup

# Cron job (daily at 2:00)
0 2 * * * cd /path/to/logs && make backup > /dev/null 2>&1
```

---

### Q: What does backup contain?

**A:** 
- `make backup` - only MongoDB (configuration, users, dashboards)
- Logs are in OpenSearch - separate backup if needed

---

### Q: How do I move Graylog to another server?

**A:**
1. Backup on old server: `make backup`
2. Copy: `.env`, `backup/`, `docker-compose.yml`
3. On new server: `make start`
4. Restore MongoDB (see SETUP_GUIDE.md)

---

## Troubleshooting

### Q: Graylog won't start - "Deflector exists"

**A:**
```bash
# 1. Stop everything
make stop

# 2. Clean OpenSearch data
docker volume rm logs_opensearch_data

# 3. Restart
make start
```

⚠️ This will remove logs!

---

### Q: "vm.max_map_count too low" on Linux

**A:**
```bash
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

---

### Q: MongoDB authentication failed

**A:**
1. Check password in `.env`
2. If you changed password, remove volume:
```bash
make stop
docker volume rm logs_mongodb_data
make start
```

⚠️ This will remove configuration!

---

### Q: High CPU usage by OpenSearch

**A:**
```bash
# Temporarily - decrease refresh interval
curl -X PUT "localhost:9200/graylog_*/_settings" -H 'Content-Type: application/json' -d'
{
  "index": {
    "refresh_interval": "30s"
  }
}'
```

Or increase `OPENSEARCH_HEAP_SIZE` in `.env`.

---

### Q: Containers keep restarting

**A:**
```bash
# View logs
make logs

# Most common causes:
# 1. Too little RAM - increase Docker memory limit
# 2. Invalid .env - run: make validate
# 3. Port conflict - change ports in .env
```

---

## Integrations

### Q: How do I integrate with Grafana?

**A:** Grafana can read from OpenSearch:
1. Grafana → Add Data Source
2. Choose OpenSearch
3. URL: `http://opensearch:9200` (if in same network)
4. Index: `graylog_*`

But this requires exposing OpenSearch port (not recommended).

Better: use Graylog API as datasource.

---

### Q: How do I send logs from Kubernetes?

**A:** Use Fluentd or Fluent Bit with output to Graylog GELF.

**Fluent Bit ConfigMap:**
```yaml
[OUTPUT]
    Name  gelf
    Match *
    Host  graylog-service.namespace.svc.cluster.local
    Port  12201
    Mode  udp
```

---

### Q: How do I integrate with Slack/Discord/Teams?

**A:** 
1. **Alerts → Notifications**
2. **Create Notification**
3. Choose **HTTP Notification**
4. Provide webhook URL from Slack/Discord/Teams
5. Configure JSON payload

Examples in Slack/Discord webhook documentation.

---

## Other

### Q: Can I use Elasticsearch instead of OpenSearch?

**A:** Theoretically yes, but:
- OpenSearch is Elasticsearch fork (compatible)
- Graylog 5.x officially supports OpenSearch
- Elasticsearch requires license in some cases

We don't recommend - stick with OpenSearch.

---

### Q: Where can I find more help?

**A:**
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - detailed guide
- [Graylog Docs](https://docs.graylog.org/)
- [Graylog Community](https://community.graylog.org/)
- GitHub Issues in this repo

---

### Q: Can I use this in production?

**A:** Yes, but:
- ✅ Use `docker-compose.prod.yml`
- ✅ Add HTTPS (reverse proxy)
- ✅ Configure regular backup
- ✅ Monitoring (Prometheus + Grafana)
- ✅ Change all default passwords
- ✅ Resource limits
- ✅ Log rotation in Graylog

---

### Q: License - can I use commercially?

**A:** 
- This setup: see [LICENSE](LICENSE)
- Graylog: Open Source (SSPL) - can be used commercially
- MongoDB: SSPL license - can be used commercially
- OpenSearch: Apache 2.0 - can be used commercially

Always check current upstream licenses!

---

**Didn't find your answer?** Open an [Issue on GitHub](https://github.com) or see [CONTRIBUTING.md](CONTRIBUTING.md)!
