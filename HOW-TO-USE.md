![Docker Pulls](https://img.shields.io/docker/pulls/eidyev/symfony-webapp-server)
![Image Size](https://img.shields.io/docker/image-size/eidyev/symfony-webapp-server/latest)
![GitHub Stars](https://img.shields.io/github/stars/eidyev/symfony-webapp-server?style=social)


# 📖 How to Use Symfony Webapp Server

This guide provides detailed instructions for using the Symfony Webapp Server Docker image in different environments.

## 🐳 Quick Start with Docker

### Development Environment

```bash
    docker run -d \
      -p 8080:80 \
      -v $(pwd)/my-app:/var/www/html \
      -e APP_ENV=dev \
      --name symfony-dev \
      eidyev/symfony-webapp-server:php-8.3-dev
      
      
   docker run -d  \
      -p 8083:80   
      -v $(pwd)/sfwebapp:/var/www/html \
      -e LOCALE=es_ES.UTF-8  \
      -e TIMEZONE=Europe/Madrid  \
      -e UID=$(id -u) \
      -e GID=$(id -g) \ 
      --name mysfwebappdev \ 
      eidyev/symfony-webapp-server:php-8.3-dev   
      
      
```

### Production Environment

```bash
    docker run -d \
      -p 80:80 \
      -v $(pwd)/my-app:/var/www/html \
      --name symfony-prod \
      eidyev/symfony-webapp-server:php-8.3-prod
```

## 🚀 Docker Compose Setup

Here's a complete `docker-compose.yml` example:

```yaml
version: '3.8'

networks:
  net:
    driver: bridge

services:
  # Development Server
  dev-server:
    image: eidyev/symfony-webapp-server:php-8.3-dev
    container_name: webdev
    ports:
      - "8080:80"
    volumes:
      - ./webapp:/var/www/html
      - ./config/php.ini-dev:/etc/php/8.3/fpm/php.ini
    environment:
      - APP_ENV=dev
      - MAILER_DSN=smtp://mailpit:1025
    depends_on:
      - db
    networks:
      - net
    profiles:
      - development

  # Production Server
  prod-server:
    image: eidyev/symfony-webapp-server:php-8.3-prod
    container_name: webprod
    ports:
      - "80:80"
    volumes:
      - ./webapp:/var/www/html
    environment:
      - APP_ENV=prod
    depends_on:
      - db
    networks:
      - net
    restart: unless-stopped
    profiles:
      - production

  # Database
  db:
    image: postgres:16-alpine
    container_name: database
    environment:
      POSTGRES_DB: ${DB_DATABASE}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    healthcheck:
      test: ["CMD", "pg_isready", "-d", "${DB_DATABASE}", "-U", "${DB_USER}"]
      timeout: 5s
      retries: 5
      start_period: 60s
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - net
    profiles:
      - development
      - production

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: redis
    volumes:
      - redis_data:/data
    networks:
      - net
    profiles:
      - development
      - production

  # Mailpit (Development only)
  mailpit:
    image: axllent/mailpit
    container_name: mailpit
    environment:
      MP_SMTP_AUTH_ACCEPT_ANY: 1
      MP_SMTP_AUTH_ALLOW_INSECURE: 1
    ports:
      - "1025:1025"  # SMTP port
      - "8025:8025"  # Web interface
    networks:
      - net
    profiles:
      - development

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
```

## 🔧 Configuration

### PHP Configuration

Customize PHP settings by mounting your own configuration:

```yaml
volumes:
  - ./config/php.ini-dev:/etc/php/8.3/fpm/php.ini
  - ./config/php-fpm.conf:/etc/php/8.3/fpm/pool.d/www.conf
```

### Nginx Configuration

Override default Nginx configuration:

```yaml
volumes:
  - ./config/nginx.conf:/etc/nginx/conf.d/default.conf
```

## 🔍 Debugging

### Xdebug (Development Only)

Xdebug is pre-configured in the development image. Use these IDE settings:

- **Host**: localhost
- **Port**: 9003
- IDE Key: PHPSTORM

## 🚀 Deployment

### Building Custom Image

```bash
  docker build --target production -t my-symfony-app .
```

### Kubernetes Deployment

Example deployment YAML:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: symfony-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: symfony
  template:
    metadata:
      labels:
        app: symfony
    spec:
      containers:
      - name: symfony
        image: eidyev/symfony-webapp-server:php-8.3-prod
        ports:
        - containerPort: 80
        envFrom:
        - secretRef:
            name: symfony-secrets
        volumeMounts:
        - name: app-storage
          mountPath: /var/www/html/var
      volumes:
      - name: app-storage
        persistentVolumeClaim:
          claimName: symfony-storage
```

## 📚 Next Steps

- [Official Symfony Documentation](https://symfony.com/doc/current/index.html)
- [Docker Documentation](https://docs.docker.com/)
- [Nginx Configuration](https://www.nginx.com/resources/wiki/start/)

## 🤝 Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/yourusername/symfony-webapp-server/issues) page.
