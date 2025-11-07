# 📖 Cómo Usar Symfony Webapp Server

Esta guía proporciona instrucciones detalladas para usar la imagen Docker de Symfony Webapp Server en diferentes entornos.

## 🐳 Inicio Rápido con Docker

### Entorno de Desarrollo

```bash
docker run -d \
  -p 8080:80 \
  -v $(pwd)/mi-aplicacion:/var/www/html \
  -e APP_ENV=dev \
  --name symfony-dev \
  eidyev/symfony-webapp-server:php-8.3-dev
```

### Entorno de Producción

```bash
docker run -d \
  -p 80:80 \
  -v $(pwd)/mi-aplicacion:/var/www/html \
  -e APP_ENV=prod \
  --name symfony-prod \
  eidyev/symfony-webapp-server:php-8.3-prod
```

## 🚀 Configuración con Docker Compose

Aquí tienes un ejemplo completo de `docker-compose.yml`:

```yaml
version: '3.8'

networks:
  net:
    driver: bridge

services:
  # Servidor de Desarrollo
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

  # Servidor de Producción
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

  # Base de Datos
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

  # Mailpit (Solo desarrollo)
  mailpit:
    image: axllent/mailpit
    container_name: mailpit
    environment:
      MP_SMTP_AUTH_ACCEPT_ANY: 1
      MP_SMTP_AUTH_ALLOW_INSECURE: 1
    ports:
      - "1025:1025"  # Puerto SMTP
      - "8025:8025"  # Interfaz web
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

## 🔧 Configuración

### Configuración de PHP

Personaliza la configuración de PHP montando tu propio archivo de configuración:

```yaml
volumes:
  - ./config/php.ini-dev:/etc/php/8.3/fpm/php.ini
  - ./config/php-fpm.conf:/etc/php/8.3/fpm/pool.d/www.conf
```

### Configuración de Nginx

Sobrescribe la configuración predeterminada de Nginx:

```yaml
volumes:
  - ./config/nginx.conf:/etc/nginx/conf.d/default.conf
```

## 🔍 Depuración

### Xdebug (Solo Desarrollo)

Xdebug viene preconfigurado en la imagen de desarrollo. Usa estos ajustes en tu IDE:

- **Host**: localhost
- **Puerto**: 9003
- Clave del IDE: PHPSTORM

## 🚀 Despliegue

### Construir Imagen Personalizada

```bash
docker build --target production -t mi-aplicacion-symfony .
```

### Despliegue en Kubernetes

Ejemplo de YAML para despliegue:

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

## 📚 Siguientes Pasos

- [Documentación Oficial de Symfony](https://symfony.com/doc/current/index.html)
- [Documentación de Docker](https://docs.docker.com/)
- [Configuración de Nginx](https://www.nginx.com/resources/wiki/start/)

## 🤝 Soporte

Para problemas y solicitudes de características, por favor usa la página de [GitHub Issues](https://github.com/tuusuario/symfony-webapp-server/issues).
