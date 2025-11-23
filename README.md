![Docker Pulls](https://img.shields.io/docker/pulls/eidyev/symfony-webapp-server)
![Image Size](https://img.shields.io/docker/image-size/eidyev/symfony-webapp-server/latest)
![GitHub Stars](https://img.shields.io/github/stars/eidyev/symfony-webapp-server?style=social)

# 🚀 Symfony Webapp Server

A production-ready Docker image for Symfony applications with **Nginx + PHP 8.X FPM + Supervisor**. Includes two optimized targets: **development** (with Xdebug and development tools) and **production** (optimized for performance).

## 🌟 Features

### Core Stack
- **Debian Bookworm** (slim)
- **Nginx** - High-performance web server
- **PHP 8.X-FPM** - With 50+ pre-installed extensions
- **Supervisor** - Process management
- **Composer** - PHP dependency manager

### Included PHP Extensions

Our image includes **50+ PHP extensions** with a **fault-tolerant** installation system:

- ✅ **No failures** if an extension isn't available for your PHP version
- 📊 **Shows a summary** in build logs
- 🔄 **Compatible** with PHP 8.0, 8.1, 8.2, 8.3, 8.4, 8.5

**Main extensions:**
```
Core, PDO, Opcache, APCu, Redis, Memcached, 
MySQL, PostgreSQL, SQLite, MongoDB, LDAP, AMQP,
GD, Imagick, SOAP, XML, YAML, ZIP, cURL, Swoole,
gRPC, Protobuf, Intl, MBString, BCMath, GMP, and more...
```

### Development Tools (development target only)
- **Symfony CLI**
- **Xdebug** 3.x
- **XHProf** - Performance profiling
- **PHPDbg** - Debugger

## 🚀 Quick Start

### Using Docker Compose (Recommended)

1. **Clone this repository:**
   ```bash
   git clone <your-repo>
   cd symfony-webapp-server
   ```

2. **Place your Symfony application in `./webapp/`:**
   ```bash
   # Create a new Symfony project
   symfony new webapp --webapp
   
   # Or copy an existing one
   cp -r /path/to/your/app ./webapp/
   ```

3. **Configure environment variables:**
   ```bash
   cp .env .env.local
   # Edit .env.local with your values
   ```

4. **Start the services:**
   ```bash
   # Development
   docker-compose up -d
   
   # Production
   COMPOSE_PROFILES=production docker-compose up -d
   ```

5. **Access your application:**
   - **Development:** http://localhost:8080
   - **Production:** http://localhost:8081
   - **Mailpit (dev only):** http://localhost:8025

## 🛠️ Manual Build

### Build development image
```bash
docker build --target development --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t symfony-dev .
```

### Build production image
```bash
docker build --target production -t symfony-prod .
```

### Run container
```bash
# Development (mounts your app as volume)
docker run -d \
  -p 8080:80 \
  -v $(pwd)/my-app:/var/www/html \
  -e APP_ENV=dev \
  --name symfony-dev \
  eidyev/symfony-webapp-server:php-8.3-dev

# Production
docker run -d \
  -p 80:80 \
  -v $(pwd)/my-app:/var/www/html \
  -e APP_ENV=prod \
  --name symfony-prod \
  eidyev/symfony-webapp-server:php-8.3-prod
```

## 📁 Project Structure

```
symfony-webapp-server/
├── config/
│   ├── nginx-default.conf      # Nginx configuration
│   ├── supervisord.conf        # Supervisor configuration
│   ├── php.ini-dev             # PHP config for development
│   └── php.ini-prod            # PHP config for production
├── scripts/                    # Scripts
│   └── entrypoint.sh           # Initialization script
├── webapp/                     # ⚠️ MOUNT YOUR APP HERE
│   └── (your Symfony app)
├── .dockerignore
├── .env                       # Environment variables
├── docker-compose.yml         # Service orchestration
├── Dockerfile                 # Multi-stage build

```

## ℹ️ Notes
- Container expects your symfony app in `/var/www/html/`
- Container expects **webroot at `/var/www/html/public`**.
- HTTPS should be handled by your reverse proxy (Traefik / Cloudflare Tunnel / Caddy).




## 🔧 Configuration

### Main Environment Variables

Edit the `.env` file with your values:

```bash
# Docker Compose profile
COMPOSE_PROFILES=development  # or "production"

# User/Group (development)
UID=1000
GID=1000

# Database
DB_HOST=database
DB_DATABASE=myapp
DB_USER=myapp_user
DB_PASSWORD=SecurePassword123

# Symfony
APP_ENV=dev                    # dev | prod | test
APP_DEBUG=1                    # 0 | 1
APP_SECRET=your_32_char_secret

# Doctrine
DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:5432/${DB_DATABASE}"

# Mailer (Mailpit in dev)
MAILER_DSN=smtp://mailpit:1025
```

### Optional deploy/ folder (first-run & update automation)

If your Symfony app includes a deploy/ folder at the project root (mounted as /var/www/html/deploy inside the container), the image can automatically run custom commands on first run and on version changes.

Expected structure:

/deploy/ firstrun.cmds # commands executed ONLY once (first container start) updtrun.cmds # commands executed when the app version changes version # current app version (e.g. 1.0.0)

    firstrun.cmds – runs only the first time the container starts with that volume (e.g. composer install, DB creation, initial migrations, seeds, etc.).

    updtrun.cmds – runs only when deploy/version changes (e.g. migrations, cache warmup, data updates).

    version – plain text file with any version string you like (1, 1.0.0, 2025-11-22, …).

To apply an update:

Change your code.

Update the value in deploy/version (for example 1.0.0 → 1.1.0).

Restart the container:

docker restart <container-name>

On restart, the entrypoint will:

Run firstrun.cmds only once (first ever start).

Run updtrun.cmds only when the version value changes.

Do nothing if the version is the same.








## 📚 Documentation

For detailed usage instructions, see [HOW-TO-USE.md](HOW-TO-USE.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is open source and available under the [MIT License](LICENSE).


##  Docker hub link
https://hub.docker.com/r/eidyev/symfony-webapp-server
