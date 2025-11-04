#!/bin/bash

# Graylog stack monitoring script
# Checks health of all services and displays status

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear

echo -e "${BLUE}╔════════════════════════════════════════╗"
echo -e "║    Graylog Stack - Monitor             ║"
echo -e "╚════════════════════════════════════════╝${NC}"
echo ""

# Function to check if container is running
check_container() {
    local name=$1
    local status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null)
    
    if [ -z "$status" ]; then
        echo -e "${RED}✗${NC} $name: Not found"
        return 1
    elif [ "$status" = "running" ]; then
        local uptime=$(docker inspect -f '{{.State.StartedAt}}' "$name" | xargs -I {} date -jf "%Y-%m-%dT%H:%M:%S" {} "+%s" 2>/dev/null || docker inspect -f '{{.State.StartedAt}}' "$name" | xargs -I {} date -d {} "+%s")
        local now=$(date "+%s")
        local diff=$((now - uptime))
        local hours=$((diff / 3600))
        local minutes=$(((diff % 3600) / 60))
        echo -e "${GREEN}✓${NC} $name: Running (${hours}h ${minutes}m)"
        return 0
    else
        echo -e "${RED}✗${NC} $name: $status"
        return 1
    fi
}

# Function to check healthcheck
check_health() {
    local name=$1
    local health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null)
    
    if [ -z "$health" ]; then
        echo "  Health: N/A"
    elif [ "$health" = "healthy" ]; then
        echo -e "  Health: ${GREEN}✓ Healthy${NC}"
    elif [ "$health" = "unhealthy" ]; then
        echo -e "  Health: ${RED}✗ Unhealthy${NC}"
    else
        echo -e "  Health: ${YELLOW}⚠ $health${NC}"
    fi
}

# Function to display resource usage
check_resources() {
    local name=$1
    local stats=$(docker stats "$name" --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}" 2>/dev/null)
    
    if [ -n "$stats" ]; then
        local cpu=$(echo "$stats" | cut -d'|' -f1)
        local mem=$(echo "$stats" | cut -d'|' -f2)
        echo "  CPU: $cpu | RAM: $mem"
    fi
}

# Check containers
echo -e "${BLUE}📦 Container status:${NC}"
echo ""

check_container "graylog_mongodb"
check_health "graylog_mongodb"
check_resources "graylog_mongodb"
echo ""

check_container "graylog_opensearch"
check_health "graylog_opensearch"
check_resources "graylog_opensearch"
echo ""

check_container "graylog_server"
check_health "graylog_server"
check_resources "graylog_server"
echo ""

# Check endpoints
echo -e "${BLUE}🌐 Endpoint status:${NC}"
echo ""

# Graylog Web UI
if curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/ 2>/dev/null | grep -q "200\|302"; then
    echo -e "${GREEN}✓${NC} Graylog Web UI: http://localhost:9000"
else
    echo -e "${RED}✗${NC} Graylog Web UI: Unavailable"
fi

# Graylog API
if curl -s http://localhost:9000/api/ 2>/dev/null | grep -q "cluster_id"; then
    echo -e "${GREEN}✓${NC} Graylog API: Responding"
else
    echo -e "${RED}✗${NC} Graylog API: Not responding"
fi

echo ""

# Port information
echo -e "${BLUE}🔌 Listening ports:${NC}"
echo ""
echo "  Web UI:    http://localhost:9000"
echo "  Syslog:    UDP/TCP 1514"
echo "  GELF:      UDP/TCP 12201"
echo ""

# Check volumes
echo -e "${BLUE}💾 Docker volumes:${NC}"
echo ""
docker volume ls --filter name=logs_ --format "  {{.Name}}: {{.Size}}" 2>/dev/null || echo "  Size information unavailable"
echo ""

# Recent logs (if there are errors)
echo -e "${BLUE}📋 Recent logs (errors):${NC}"
echo ""

ERRORS=$(docker-compose logs --tail=50 2>&1 | grep -i "error\|exception\|failed" | tail -5)
if [ -n "$ERRORS" ]; then
    echo -e "${RED}$ERRORS${NC}"
else
    echo -e "${GREEN}  No errors in last 50 log lines${NC}"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗"
echo -e "║  Refresh: ./monitor.sh                 ║"
echo -e "║  More logs: make logs                  ║"
echo -e "╚════════════════════════════════════════╝${NC}"
