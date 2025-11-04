#!/bin/bash

# Graylog configuration validation script
# Checks if everything is properly configured before starting

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================"
echo "  Graylog - Configuration Validation"
echo "======================================${NC}"
echo ""

ERRORS=0
WARNINGS=0

# Helper functions
error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    ((ERRORS++))
}

warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
    ((WARNINGS++))
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# 1. Check Docker
echo "🐳 Checking Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    success "Docker installed: $DOCKER_VERSION"
else
    error "Docker is not installed"
fi

# 2. Check Docker Compose
echo ""
echo "🐳 Checking Docker Compose..."
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | tr -d ',')
    success "Docker Compose installed: $COMPOSE_VERSION"
elif docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short)
    success "Docker Compose (plugin) installed: $COMPOSE_VERSION"
else
    error "Docker Compose is not installed"
fi

# 3. Check .env file
echo ""
echo "📄 Checking .env file..."
if [ ! -f .env ]; then
    error ".env file does not exist! Run: ./setup.sh"
else
    success ".env file exists"
    
    # Check required variables
    REQUIRED_VARS=(
        "MONGODB_USER"
        "MONGODB_PASSWORD"
        "OPENSEARCH_PASSWORD"
        "GRAYLOG_PASSWORD_SECRET"
        "GRAYLOG_ROOT_PASSWORD_SHA2"
        "GRAYLOG_HTTP_EXTERNAL_URI"
    )
    
    for var in "${REQUIRED_VARS[@]}"; do
        if ! grep -q "^${var}=" .env; then
            error "Missing variable ${var} in .env"
        else
            value=$(grep "^${var}=" .env | cut -d'=' -f2-)
            if [ -z "$value" ]; then
                error "Variable ${var} is empty"
            elif [[ "$value" == "changeme"* ]] || [[ "$value" == "ChangeMeOpenSearch"* ]]; then
                warning "Variable ${var} has default value - change it!"
            else
                success "Variable ${var} is set"
            fi
        fi
    done
    
    # Check PASSWORD_SECRET length
    PASSWORD_SECRET=$(grep "^GRAYLOG_PASSWORD_SECRET=" .env | cut -d'=' -f2-)
    if [ ${#PASSWORD_SECRET} -lt 16 ]; then
        error "GRAYLOG_PASSWORD_SECRET must be at least 16 characters (currently: ${#PASSWORD_SECRET})"
    else
        success "GRAYLOG_PASSWORD_SECRET has proper length (${#PASSWORD_SECRET} characters)"
    fi
    
    # Check SHA2 format
    ROOT_PASSWORD_SHA2=$(grep "^GRAYLOG_ROOT_PASSWORD_SHA2=" .env | cut -d'=' -f2-)
    if [ ${#ROOT_PASSWORD_SHA2} -ne 64 ]; then
        error "GRAYLOG_ROOT_PASSWORD_SHA2 should be a 64-character SHA256 hash (currently: ${#ROOT_PASSWORD_SHA2})"
    else
        success "GRAYLOG_ROOT_PASSWORD_SHA2 has correct format"
    fi
fi

# 4. Check docker-compose.yml
echo ""
echo "📄 Checking docker-compose.yml..."
if [ ! -f docker-compose.yml ]; then
    error "docker-compose.yml file does not exist!"
else
    success "docker-compose.yml file exists"
    
    # Validate syntax
    if docker-compose config > /dev/null 2>&1 || docker compose config > /dev/null 2>&1; then
        success "docker-compose.yml syntax is correct"
    else
        error "Error in docker-compose.yml syntax"
    fi
fi

# 5. Check ports
echo ""
echo "🔌 Checking port availability..."
PORTS=(9000 1514 12201)
for port in "${PORTS[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        warning "Port $port is already in use"
    else
        success "Port $port is available"
    fi
done

# 6. Check disk space
echo ""
echo "💾 Checking disk space..."
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}')
AVAILABLE_SPACE_GB=$(df -BG . | awk 'NR==2 {print $4}' | tr -d 'G')

if [ "$AVAILABLE_SPACE_GB" -lt 10 ]; then
    warning "Low disk space: $AVAILABLE_SPACE (recommended minimum: 10GB)"
else
    success "Available space: $AVAILABLE_SPACE"
fi

# 7. Check RAM
echo ""
echo "💻 Checking RAM..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    TOTAL_RAM=$(sysctl hw.memsize | awk '{print int($2/1024/1024/1024)}')
else
    # Linux
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
fi

if [ "$TOTAL_RAM" -lt 4 ]; then
    warning "System has only ${TOTAL_RAM}GB RAM (recommended minimum: 4GB)"
else
    success "Available RAM: ${TOTAL_RAM}GB"
fi

# 8. Check if Docker is running
echo ""
echo "🔄 Checking if Docker daemon is running..."
if docker ps > /dev/null 2>&1; then
    success "Docker daemon is running"
else
    error "Docker daemon is not running - start Docker Desktop or dockerd"
fi

# 9. Check existing containers
echo ""
echo "📦 Checking existing containers..."
CONTAINERS=("graylog_mongodb" "graylog_opensearch" "graylog_server")
RUNNING=0
for container in "${CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        info "Container ${container} already exists"
        ((RUNNING++))
    fi
done

if [ $RUNNING -gt 0 ]; then
    warning "Found $RUNNING existing containers - may need: make clean"
fi

# 10. Check network connectivity
echo ""
echo "🌐 Checking connection to Docker Hub..."
if docker pull hello-world:latest > /dev/null 2>&1; then
    success "Connection to Docker Hub works"
    docker rmi hello-world:latest > /dev/null 2>&1
else
    warning "Cannot connect to Docker Hub - check internet connection"
fi

# Summary
echo ""
echo -e "${BLUE}======================================"
echo "  Summary"
echo "======================================${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ Everything OK! You can run: make start${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Found $WARNINGS warnings${NC}"
    echo -e "${YELLOW}You can continue, but we recommend fixing warnings${NC}"
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS errors and $WARNINGS warnings${NC}"
    echo -e "${RED}Fix errors before starting!${NC}"
    exit 1
fi
