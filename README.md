# Docker Compose Deployment Template

A flexible Docker Compose deployment template with service orchestration, configuration management, and automated workflows.

## Features

- **Service Orchestration**: Define and manage multiple services with dependency resolution
- **Configuration Merging**: Automatically merge Docker Compose files and environment variables
- **Automated Workflows**: Simple Make commands for common operations
- **Project Isolation**: Clean up only project-specific resources
- **Flexible Deployment**: Support for multiple deployment scenarios

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Make utility
- Bash shell

### Basic Usage

```bash
# Build and configure services
make build nginx84 redis

# Start services
make up

# Check status
docker ps

# Stop services
make down

# Clean up (removes containers, volumes, and merged files)
make clean
```

## Available Commands

### make build `<service1> [service2] ...`

Build and configure services with automatic dependency resolution.

```bash
make build nginx84 redis
make build nginx84
```

**What it does:**
- Resolves service dependencies
- Merges Docker Compose configurations
- Merges environment files
- Creates merged files in root directory

### make up

Start services using the merged configuration files.

```bash
make up
```

**What it does:**
- Finds merged compose and env files in root directory
- Starts services with docker-compose up -d

### make down

Stop services and remove containers, networks.

```bash
make down
```

**What it does:**
- Stops all services
- Removes containers
- Removes networks
- Removes orphaned containers (optional)

### make clean

Full cleanup of project resources.

```bash
make clean
```

**What it does:**
- Shuts down all docker-compose configurations
- Removes project-specific containers, volumes, and networks
- Removes merged files (keeps `.env` and `docker-compose.yml`)
- Cleans up orphaned resources

## Project Structure

```
.
├── deployment/
│   ├── scripts/
│   │   ├── build.sh      # Build and merge services
│   │   ├── up.sh         # Start services
│   │   ├── down.sh       # Stop services
│   │   └── clean.sh      # Full cleanup
│   ├── services/         # Service definitions
│   │   ├── nginx84/
│   │   │   ├── docker-compose.yml
│   │   │   ├── .env.dist
│   │   │   └── ...
│   │   └── redis/
│   │       ├── docker-compose.yml
│   │       └── .env.dist
│   └── temp/             # Temporary merged files
├── services.yaml         # Service definitions and dependencies
├── docker-compose.yml    # Auto-generated compose file
├── .env                  # Auto-generated environment file
└── Makefile              # Command shortcuts
```

## Service Configuration

### services.yaml

Define services and their dependencies:

```yaml
services:
  redis:
    compose: deployment/services/redis/docker-compose.yml
    env: deployment/services/redis/.env.dist
    # No dependencies
  
  nginx84:
    compose: deployment/services/nginx84/docker-compose.yml
    env: deployment/services/nginx84/.env.dist
    depends: [redis]  # Start redis before nginx84
```

### Service Directory Structure

Each service has its own directory under `deployment/services/`:

```
deployment/services/{service_name}/
├── docker-compose.yml   # Service-specific compose file
├── .env.dist           # Environment variables template
└── ...                 # Additional files (configs, scripts, etc.)
```

## Advanced Usage

### Script Options

All scripts support verbose and quiet modes:

```bash
# Verbose output
./deployment/scripts/build.sh --verbose nginx84 redis

# Quiet mode (default in Makefile)
./deployment/scripts/build.sh --quiet nginx84 redis

# Show help
./deployment/scripts/build.sh --help
```

### Custom YAML File

Specify a custom services configuration file:

```bash
./deployment/scripts/build.sh --yaml custom-services.yaml nginx84 redis
```

### Interactive Mode

Enable interactive prompts for file operations:

```bash
./deployment/scripts/build.sh --interactive nginx84 redis
```

### Starting Without Orphans

Stop services without removing orphaned containers:

```bash
make down
# or
./deployment/scripts/down.sh --no-orphans
```

## Workflow Examples

### Initial Setup

```bash
# Build and configure services
make build nginx84 redis

# Start services
make up

# Check logs
docker-compose logs -f

# Stop when done
make down
```

### Development Workflow

```bash
# Start services
make up

# Make changes to service configs
# ...

# Rebuild if configs changed
make build nginx84 redis

# Stop and start again
make down
make up

# When finished
make clean
```

### Clean Rebuild

```bash
# Clean everything
make clean

# Rebuild from scratch
make build nginx84 redis
```

## Troubleshooting

### Services Won't Start

```bash
# Check for port conflicts
docker ps -a

# View service logs
docker-compose logs

# Full cleanup and restart
make clean
make build nginx84 redis
```

### Merged Files Issues

```bash
# Remove all merged files manually
rm -f docker-compose.merged.yml .env.merged
rm -f deployment/temp/docker-compose.merged.yml deployment/temp/.env.merged

# Rebuild
make build nginx84 redis
```

### Container Naming Conflicts

```bash
# Stop and remove all project containers
make down

# Or full cleanup
make clean
```

## File Management

### Merged Files

- `docker-compose.merged.yml` - Merged compose configuration
- `.env.merged` - Merged environment variables
- `docker-compose.yml` - Auto-created from merged files
- `.env` - Auto-created from merged files

### Clean Behavior

- **make clean** keeps `.env` and `docker-compose.yml`
- **make clean** removes `*.merged` files
- Use `make clean` to prepare for fresh `make up`

### Generated Files Location

- Root directory: User-facing compose and env files
- `deployment/temp/`: Working directory for merges

## Contributing

1. Follow the existing service structure
2. Add service definitions to `services.yaml`
3. Create service directory under `deployment/services/`
4. Test with `make build` and `make clean`

## License

[MIT License](LICENSE)

## Author

[Konstantin Budylov: k.budylov@gmail.com]
