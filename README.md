# WordPress Deployment Template

🚀 Professional template for deploying WordPress using Docker, Nginx, PHP 8.4, MySQL, and phpMyAdmin. Includes automatic service orchestration, configuration management, and convenient commands for development.

## ✨ Features

- **WordPress** with full PHP 8.4 support and all necessary extensions
- **Nginx** with HTTP/HTTPS support and SSL certificates
- **MySQL 8.0** with automatic database initialization
- **phpMyAdmin** for convenient database management
- **Xdebug** for PHP debugging
- **Redis/PostgreSQL** support out of the box
- **Automatic service orchestration** with dependency resolution
- **Convenient Make commands** for project management
- **Health checks** for all services
- **Project isolation** via Docker volumes and networks

## 📋 Requirements

- Docker Engine 20.10+
- Docker Compose V2
- Make utility
- Bash shell (macOS/Linux)

## 🚀 Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone <repository-url> my-wordpress-project
cd my-wordpress-project

# Create .env file from example
cp .env.example .env

# Edit .env for your needs (optional)
nano .env
```

### 2. Launch Project

```bash
# Build and configure services
make build nginx84 mysql

# Start all services
make up

# Check status
docker ps
```

### 3. Access Services

- **WordPress**: http://localhost:80 (or port from HTTP_PORT)
- **WordPress (HTTPS)**: https://localhost:443 (or port from HTTPS_PORT)
- **phpMyAdmin**: http://localhost:8080 (or port from PHPMYADMIN_PORT)
- **MySQL**: localhost:3306 (or port from DB_PORT)

### 4. Install WordPress

After starting services, open WordPress in your browser and follow the installer instructions or use the existing WordPress installation in the `./wordpress` directory.

## 📁 Project Structure

```
wp-deployment-template/
├── wordpress/                  # WordPress files
│   ├── wp-content/            # Themes, plugins, uploads
│   ├── wp-config.php          # WordPress configuration
│   └── ...
├── deployment/                # Docker configuration
│   ├── scripts/               # Management scripts
│   │   ├── build.sh          # Build and merge configurations
│   │   ├── up.sh             # Start services
│   │   ├── down.sh           # Stop services
│   │   ├── restart.sh        # Restart services
│   │   └── clean.sh          # Full cleanup
│   ├── services/             # Service definitions
│   │   ├── nginx84/          # Nginx + PHP 8.4
│   │   │   ├── build/        # Dockerfile
│   │   │   │   └── Dockerfile
│   │   │   ├── conf/         # Nginx/PHP/Xdebug configurations
│   │   │   │   ├── nginx.conf
│   │   │   │   ├── ssl.conf
│   │   │   │   └── xdebug.ini
│   │   │   ├── ssl/          # SSL certificates
│   │   │   ├── docker-compose.yml
│   │   │   └── .env.dist
│   │   └── mysql/            # MySQL 8.0
│   │       ├── init/         # SQL initialization scripts
│   │       ├── docker-compose.yml
│   │       └── .env.dist
│   └── temp/                 # Temporary merge files
├── services.yaml             # Service definitions and dependencies
├── docker-compose.yml        # Main Docker Compose configuration
├── .env.example              # Environment variables example
├── .env                      # Your environment variables (created)
├── Makefile                  # Project management commands
├── composer.json             # Composer configuration
└── README.md                 # This file
```

## ⚙️ Configuration

### Environment Variables (.env)

Create a `.env` file based on `.env.example`:

```dotenv
# Docker Compose project name
COMPOSE_PROJECT_NAME=wordpress-template

# Service ports
PHPMYADMIN_PORT=8080    # phpMyAdmin web interface
HTTP_PORT=80            # Nginx HTTP
HTTPS_PORT=443          # Nginx HTTPS

# MySQL database
DB_PORT=3306
DB_NAME=wordpress       # Database name
DB_USER=wp              # Database user
DB_PASSWORD=wp_pass     # User password
DB_ROOT_PASSWORD=root   # MySQL root password

# WordPress settings
WP_URL=http://localhost:8080
WP_TITLE='My WP Site'
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=admin
WP_ADMIN_EMAIL=admin@example.com
WP_DIR=./wordpress      # Path to WordPress files
```

### Service Configuration (services.yaml)

Defines services and their dependencies:

```yaml
nginx84:
  compose: deployment/services/nginx84/docker-compose.yml
  env: deployment/services/nginx84/.env.dist
  depends:
    - mysql

mysql:
  compose: deployment/services/mysql/docker-compose.yml
  env: deployment/services/mysql/.env.dist
```

## 🛠️ Management Commands

### Main Commands

#### `make build <service1> [service2] ...`

Build and configure services with automatic dependency resolution.

```bash
make build nginx84 mysql    # Build both services
make build nginx84          # Build nginx84 (mysql will be added automatically)
```

**What happens:**
- Resolves service dependencies
- Merges Docker Compose configurations
- Merges environment variables
- Creates `docker-compose.yml` and `.env` files in project root

#### `make up`

Start all services.

```bash
make up
```

**What happens:**
- Finds merged configurations
- Starts services in background mode (`docker-compose up -d`)
- Applies health checks

#### `make restart`

Restart services without rebuild.

```bash
make restart
```

#### `make down`

Stop services and remove containers.

```bash
make down
```

**What happens:**
- Stops all services
- Removes containers
- Removes networks
- Removes orphaned containers

#### `make clean`

Full project cleanup.

```bash
make clean
```

**What happens:**
- Stops all Docker Compose configurations
- Removes project containers, volumes and networks
- Removes temporary files from `deployment/temp/`
- Cleans up orphaned resources

#### `make help`

Show help for available commands.

```bash
make help
```

## 🔧 Advanced Usage

### Direct Script Calls

All scripts support additional options:

```bash
# Verbose mode
./deployment/scripts/build.sh --verbose nginx84 mysql

# Quiet mode (used by default in Makefile)
./deployment/scripts/build.sh --quiet nginx84

# Interactive mode
./deployment/scripts/build.sh --interactive nginx84

# Help
./deployment/scripts/build.sh --help
./deployment/scripts/up.sh --help
./deployment/scripts/down.sh --help
./deployment/scripts/clean.sh --help
```

### Custom YAML File

Using a custom service configuration file:

```bash
./deployment/scripts/build.sh --yaml custom-services.yaml nginx84 mysql
```

### Working with Docker Compose Directly

After `make build` and `make up`, you can use standard Docker Compose commands:

```bash
# View logs
docker-compose logs -f

# Logs for specific service
docker-compose logs -f wordpress

# Execute command in container
docker-compose exec wordpress bash

# View status
docker-compose ps

# Restart specific service
docker-compose restart wordpress
```

## 🐛 Working with WordPress

### Database Connection

In `wp-config.php` use the following settings:

```php
define('DB_NAME', getenv('DB_NAME') ?: 'wordpress');
define('DB_USER', getenv('DB_USER') ?: 'wp');
define('DB_PASSWORD', getenv('DB_PASSWORD') ?: 'wp_pass');
define('DB_HOST', 'db:3306');  // 'db' - service name from docker-compose.yml
```

### Installing Themes and Plugins

All WordPress files are in the `./wordpress` directory:

```bash
# Themes
./wordpress/wp-content/themes/

# Plugins
./wordpress/wp-content/plugins/

# Uploads
./wordpress/wp-content/uploads/
```

### WP-CLI

Executing WP-CLI commands:

```bash
# Enter WordPress container
docker-compose exec wordpress bash

# Install WordPress via WP-CLI (if installed)
wp core install --url="http://localhost" \
  --title="My Site" \
  --admin_user="admin" \
  --admin_password="password" \
  --admin_email="admin@example.com"

# Install plugin
wp plugin install wordpress-seo --activate

# Update all plugins
wp plugin update --all
```

## 🔍 Debugging

### Xdebug

Xdebug is already installed and configured. Configuration is located at:
```
deployment/services/nginx84/conf/xdebug.ini
```

### Viewing Logs

```bash
# All logs
docker-compose logs -f

# WordPress/Nginx/PHP logs
docker-compose logs -f wordpress

# MySQL logs
docker-compose logs -f db

# phpMyAdmin logs
docker-compose logs -f phpmyadmin
```

### Health Checks Verification

```bash
# Container status with health checks
docker ps

# Detailed health check information
docker inspect wordpress | grep -A 10 Health
```

## 📊 Working with Database

### phpMyAdmin

Access phpMyAdmin at: http://localhost:8080

**Credentials:**
- Server: `db`
- Username: value from `DB_USER` (default: `wp`)
- Password: value from `DB_PASSWORD` (default: `wp_pass`)

### MySQL CLI

```bash
# Connect to MySQL via docker-compose
docker-compose exec db mysql -u wp -p

# Or as root
docker-compose exec db mysql -u root -p

# Export database
docker-compose exec db mysqldump -u root -p wordpress > backup.sql

# Import database
docker-compose exec -T db mysql -u root -p wordpress < backup.sql
```

### Database Initialization

SQL scripts in `deployment/services/mysql/init/` are executed automatically on first MySQL startup:

```bash
deployment/services/mysql/init/
├── 01-init.sql
├── 02-data.sql
└── ...
```

## 🔒 SSL/HTTPS

SSL certificates are stored in:
```
deployment/services/nginx84/ssl/
```

For development, you can use self-signed certificates:

```bash
# Create self-signed certificate
cd deployment/services/nginx84/ssl/
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx.key -out nginx.crt \
  -subj "/C=US/ST=State/L=City/O=Dev/CN=localhost"
```

## 🔄 Workflow Examples

### Starting Work on Project

```bash
# 1. Setup environment
cp .env.example .env
nano .env

# 2. Build services
make build nginx84 mysql

# 3. Start
make up

# 4. Check status
docker ps
docker-compose logs -f
```

### Development

```bash
# Start project
make up

# Make changes to WordPress code
# Files in ./wordpress/ are automatically synced

# Restart if needed
make restart

# Stop when done
make down
```

### Clean Rebuild

```bash
# Full cleanup
make clean

# Rebuild from scratch
make build nginx84 mysql
make up
```

### Updating Service Configuration

```bash
# Stop services
make down

# Make changes to deployment/services/

# Rebuild
make build nginx84 mysql

# Start again
make up
```

## 🚨 Troubleshooting

### Services Won't Start

```bash
# Check for port conflicts
docker ps -a
lsof -i :80
lsof -i :3306

# View logs
docker-compose logs

# Full cleanup and restart
make clean
make build nginx84 mysql
make up
```

### Merged Files Issues

```bash
# Remove all merged files
rm -f docker-compose.yml .env
rm -rf deployment/temp/*

# Rebuild
make build nginx84 mysql
```

### Container Name Conflicts

```bash
# Stop and remove all project containers
make down

# Or full cleanup
make clean
```

### WordPress File Permission Errors

```bash
# Set correct permissions for WordPress
sudo chown -R www-data:www-data ./wordpress/wp-content/
sudo chmod -R 755 ./wordpress/wp-content/
```

### Database Not Initializing

```bash
# Remove MySQL volume
docker-compose down -v
docker volume rm wordpress-template_mysql_data

# Recreate
make up
```

## 📦 Adding New Services

### 1. Create Service Directory

```bash
mkdir -p deployment/services/my-service
```

### 2. Create Configuration Files

```bash
# docker-compose.yml
touch deployment/services/my-service/docker-compose.yml

# .env.dist
touch deployment/services/my-service/.env.dist
```

### 3. Add to services.yaml

```yaml
my-service:
  compose: deployment/services/my-service/docker-compose.yml
  env: deployment/services/my-service/.env.dist
  depends:
    - mysql  # Optional
```

### 4. Build and Start

```bash
make build my-service
make up
```

## 🔐 Security

### For Production

1. **Change all passwords** in `.env`
2. **Use real SSL certificates** (Let's Encrypt)
3. **Restrict access to phpMyAdmin** (or disable it)
4. **Configure firewall** to limit port access
5. **Regularly update** WordPress, themes and plugins
6. **Use strong passwords** for WordPress admin
7. **Disable Xdebug** in production
8. **Set up backups** for database and files

### .gitignore

Make sure `.env` and sensitive data are not committed:

```gitignore
.env
.env.merged
deployment/temp/*
wordpress/wp-config.php
deployment/services/*/ssl/*.key
deployment/services/*/ssl/*.crt
```

## 📄 File Management

### Merged Files

- `docker-compose.yml` - Merged Docker Compose configuration
- `.env` - Merged environment variables
- `deployment/temp/` - Working directory for temporary files

### Clean Behavior

- `make clean` **keeps** `.env` and `docker-compose.yml` in root
- `make clean` **removes** files from `deployment/temp/`
- `make clean` **removes** project Docker volumes

## 🤝 Contributing

1. Follow the existing service structure
2. Add service definitions to `services.yaml`
3. Create service directories in `deployment/services/`
4. Test using `make build` and `make clean`
5. Document your changes

## 📝 License

[MIT License](LICENSE)

## 👤 Author

**Konstantin Budylov**
- Email: k.budylov@gmail.com

## 🔗 Useful Links

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [WordPress Documentation](https://wordpress.org/documentation/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [MySQL 8.0 Documentation](https://dev.mysql.com/doc/refman/8.0/en/)
- [PHP 8.4 Documentation](https://www.php.net/docs.php)

---

Made with ❤️ for WordPress developers

