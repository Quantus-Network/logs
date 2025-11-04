#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "  Graylog Setup - Initialization"
echo "======================================"
echo ""

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed!${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}✗ Docker Compose is not installed!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker is installed${NC}"
echo -e "${GREEN}✓ Docker Compose is installed${NC}"
echo ""

# Check if .env file already exists
if [ -f .env ]; then
    echo -e "${YELLOW}⚠ .env file already exists!${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Copy template to .env
echo "Creating .env file from template..."
cp env.template .env

# Generate GRAYLOG_PASSWORD_SECRET
echo ""
echo "Generating GRAYLOG_PASSWORD_SECRET..."
PASSWORD_SECRET=$(openssl rand -base64 96 | tr -d '\n')
if [ -z "$PASSWORD_SECRET" ]; then
    echo -e "${RED}✗ Error generating password secret!${NC}"
    exit 1
fi

# Replace in .env file
sed -i.bak "s|GRAYLOG_PASSWORD_SECRET=.*|GRAYLOG_PASSWORD_SECRET=${PASSWORD_SECRET}|g" .env
rm .env.bak 2>/dev/null || true

echo -e "${GREEN}✓ Generated GRAYLOG_PASSWORD_SECRET${NC}"

# Ask for administrator password
echo ""
echo "Enter password for Graylog administrator:"
read -s -p "Password: " ADMIN_PASSWORD
echo
read -s -p "Confirm password: " ADMIN_PASSWORD_CONFIRM
echo

if [ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]; then
    echo -e "${RED}✗ Passwords do not match!${NC}"
    exit 1
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${RED}✗ Password cannot be empty!${NC}"
    exit 1
fi

# Generate SHA2 hash
echo "Generating password hash..."
ADMIN_PASSWORD_HASH=$(echo -n "$ADMIN_PASSWORD" | shasum -a 256 | cut -d" " -f1)
sed -i.bak "s|GRAYLOG_ROOT_PASSWORD_SHA2=.*|GRAYLOG_ROOT_PASSWORD_SHA2=${ADMIN_PASSWORD_HASH}|g" .env
rm .env.bak 2>/dev/null || true

echo -e "${GREEN}✓ Generated administrator password hash${NC}"

# Generate MongoDB password
echo ""
echo "Generating random password for MongoDB..."
MONGODB_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
sed -i.bak "s|MONGODB_PASSWORD=.*|MONGODB_PASSWORD=${MONGODB_PASSWORD}|g" .env
rm .env.bak 2>/dev/null || true
echo -e "${GREEN}✓ Generated MongoDB password${NC}"

# Generate OpenSearch password
echo "Generating random password for OpenSearch..."
OPENSEARCH_PASSWORD=$(openssl rand -base64 16 | tr -d '\n' | head -c 16)
# Add special characters to meet requirements
OPENSEARCH_PASSWORD="${OPENSEARCH_PASSWORD}Aa1!"
sed -i.bak "s|OPENSEARCH_PASSWORD=.*|OPENSEARCH_PASSWORD=${OPENSEARCH_PASSWORD}|g" .env
rm .env.bak 2>/dev/null || true
echo -e "${GREEN}✓ Generated OpenSearch password${NC}"

# Ask for external URL
echo ""
echo "Enter the URL where Graylog will be accessible"
echo "Examples:"
echo "  - http://localhost:9000/"
echo "  - http://logs.yourdomain.com:9000/"
echo "  - https://logs.yourdomain.com/"
read -p "URL [http://localhost:9000/]: " EXTERNAL_URI
EXTERNAL_URI=${EXTERNAL_URI:-http://localhost:9000/}

# Ensure URL ends with /
if [[ ! $EXTERNAL_URI =~ /$ ]]; then
    EXTERNAL_URI="${EXTERNAL_URI}/"
fi

sed -i.bak "s|GRAYLOG_HTTP_EXTERNAL_URI=.*|GRAYLOG_HTTP_EXTERNAL_URI=${EXTERNAL_URI}|g" .env
rm .env.bak 2>/dev/null || true

echo -e "${GREEN}✓ Set external URL${NC}"

# Summary
echo ""
echo "======================================"
echo "  Configuration complete!"
echo "======================================"
echo ""
echo "Created .env file with the following settings:"
echo ""
echo "MongoDB:"
echo "  - User: graylog"
echo "  - Password: (generated automatically)"
echo ""
echo "OpenSearch:"
echo "  - Password: (generated automatically)"
echo ""
echo "Graylog:"
echo "  - Admin username: admin"
echo "  - Admin password: (what you entered)"
echo "  - URL: ${EXTERNAL_URI}"
echo ""
echo "======================================"
echo ""
echo "To start Graylog, run:"
echo -e "${GREEN}docker-compose up -d${NC}"
echo ""
echo "To check status:"
echo -e "${GREEN}docker-compose ps${NC}"
echo ""
echo "To view logs:"
echo -e "${GREEN}docker-compose logs -f graylog${NC}"
echo ""
echo "Access Graylog at:"
echo -e "${GREEN}${EXTERNAL_URI}${NC}"
echo "Login as: admin / (your password)"
echo ""
