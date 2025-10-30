# Makefile for deployment template

# Default target
.PHONY: help
help:
	@echo "Available commands:"
	@echo "  make build <service1> [service2] ..."
	@echo "  make up"
	@echo "  make restart"
	@echo "  make down"
	@echo "  make clean"
	@echo ""
	@echo "Examples:"
	@echo "  make build nginx84 redis    # Build and configure services"
	@echo "  make build nginx84          # Build single service"
	@echo "  make up                     # Start services"
	@echo "  make restart                # Restart services"
	@echo "  make down                   # Stop services"
	@echo "  make clean                  # Full cleanup (stop, remove, delete merged files)"
	@echo ""
	@echo "For advanced options (flags), use the script directly:"
	@echo "  ./deployment/scripts/build.sh --help"
	@echo "  ./deployment/scripts/up.sh --help"
	@echo "  ./deployment/scripts/restart.sh --help"
	@echo "  ./deployment/scripts/down.sh --help"
	@echo "  ./deployment/scripts/clean.sh --help"

# Build command - runs build.sh with service names
.PHONY: build
build:
	@./deployment/scripts/build.sh --quiet $(filter-out $@,$(MAKECMDGOALS))

# Up command - runs up.sh
.PHONY: up
up:
	@./deployment/scripts/up.sh --quiet

# Restart command - runs restart.sh with existing merged files
.PHONY: restart
restart:
	@./deployment/scripts/restart.sh --quiet

# Down command - runs down.sh
.PHONY: down
down:
	@./deployment/scripts/down.sh --quiet

# Clean command - runs clean.sh
.PHONY: clean
clean:
	@./deployment/scripts/clean.sh --quiet

# Prevent make from treating service names as targets
%:
	@true
