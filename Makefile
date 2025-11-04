.PHONY: help setup validate monitor start stop restart logs logs-graylog logs-mongodb logs-opensearch status clean clean-all backup health update shell-graylog shell-mongodb shell-opensearch

help: ## Display help
	@echo "Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

setup: ## Initialize environment (generate .env)
	@./setup.sh

validate: ## Validate configuration before starting
	@./validate.sh

monitor: ## Monitor status of all services
	@./monitor.sh

start: ## Start all services
	@echo "Starting Graylog stack..."
	@docker-compose up -d
	@echo "✓ Services started"
	@echo ""
	@echo "Check status: make status"
	@echo "View logs: make logs"

stop: ## Stop all services
	@echo "Stopping services..."
	@docker-compose stop
	@echo "✓ Services stopped"

restart: ## Restart all services
	@echo "Restarting services..."
	@docker-compose restart
	@echo "✓ Services restarted"

logs: ## Display logs for all services
	@docker-compose logs -f

logs-graylog: ## Display logs for Graylog only
	@docker-compose logs -f graylog

logs-mongodb: ## Display logs for MongoDB only
	@docker-compose logs -f mongodb

logs-opensearch: ## Display logs for OpenSearch only
	@docker-compose logs -f opensearch

status: ## Status of all containers
	@echo "Service status:"
	@echo ""
	@docker-compose ps
	@echo ""
	@echo "Resource usage:"
	@docker stats --no-stream $$(docker-compose ps -q)

clean: ## Stop and remove containers (data preserved)
	@echo "⚠️  Stopping and removing containers..."
	@read -p "Continue? [y/N]: " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker-compose down; \
		echo "✓ Containers removed (data preserved in volumes)"; \
	else \
		echo "Cancelled."; \
	fi

clean-all: ## REMOVES everything including data!
	@echo "⚠️  WARNING: This will remove ALL data including logs!"
	@read -p "Are you sure you want to continue? [y/N]: " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker-compose down -v; \
		echo "✓ Everything removed"; \
	else \
		echo "Cancelled."; \
	fi

backup: ## Backup MongoDB
	@echo "Creating MongoDB backup..."
	@mkdir -p ./backups
	@docker-compose exec -T mongodb mongodump \
		--uri="mongodb://$$(grep MONGODB_USER .env | cut -d '=' -f2):$$(grep MONGODB_PASSWORD .env | cut -d '=' -f2)@localhost:27017/graylog?authSource=admin" \
		--archive > ./backups/mongodb-backup-$$(date +%Y%m%d-%H%M%S).archive
	@echo "✓ Backup saved in ./backups/"

health: ## Check service health
	@echo "Checking service health..."
	@echo ""
	@echo "MongoDB:"
	@docker-compose exec -T mongodb mongosh --quiet --eval "db.adminCommand('ping')" 2>&1 | grep -q "ok" && echo "  ✓ MongoDB is running" || echo "  ✗ MongoDB is not responding"
	@echo ""
	@echo "OpenSearch:"
	@curl -s http://localhost:9200/_cluster/health > /dev/null 2>&1 && echo "  ✓ OpenSearch is running" || echo "  ✗ OpenSearch is not accessible (this is OK, port is not exposed)"
	@echo ""
	@echo "Graylog:"
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/ | grep -q "200\|302" && echo "  ✓ Graylog is running" || echo "  ✗ Graylog is not responding"

update: ## Update Docker images
	@echo "Updating images..."
	@docker-compose pull
	@echo "✓ Images updated"
	@echo ""
	@echo "To apply changes run: make restart"

shell-graylog: ## Shell in Graylog container
	@docker-compose exec graylog /bin/bash

shell-mongodb: ## Shell in MongoDB container
	@docker-compose exec mongodb /bin/bash

shell-opensearch: ## Shell in OpenSearch container
	@docker-compose exec opensearch /bin/bash
