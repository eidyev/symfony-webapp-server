# 🚀 Imagen Docker Base para Symfony

Imagen Docker lista para producción con **Nginx + PHP 8.3 FPM + Supervisor** optimizada para aplicaciones Symfony. Incluye dos targets: **development** (con Xdebug y herramientas de desarrollo) y **production** (optimizada para rendimiento).

---

## 📦 ¿Qué incluye?

### Stack Base
- **Debian Bookworm** (slim)
- **Nginx** - Servidor web
- **PHP 8.3-FPM** - Con más de 50 extensiones instaladas
- **Supervisor** - Gestión de procesos
- **Composer** - Gestor de dependencias PHP

### Extensiones PHP Incluidas

La imagen intenta instalar **más de 50 extensiones PHP**. El sistema de instalación es **tolerante a fallos**:

- ✅ **No falla** si una extensión no está disponible para tu versión de PHP
- 📊 **Muestra un resumen** en los logs de construcción
- 🔄 **Compatible** con PHP 8.0, 8.1, 8.2, 8.3, 8.4+

**Extensiones principales:**
```
Core, PDO, Opcache, APCu, Redis, Memcached, 
MySQL, PostgreSQL, SQLite, MongoDB, LDAP, AMQP (RabbitMQ),
GD, Imagick, SOAP, XML, YAML, ZIP, cURL, Swoole,
gRPC, Protobuf, Intl, MBString, BCMath, GMP, y muchas más...
```

Durante el build verás algo como:
```
========================================
Instalando extensiones PHP 8.3
========================================
✓ Instalado: php8.3-ctype
✓ Instalado: php8.3-intl
✗ No disponible: php8.3-algunaextension
========================================
Resumen: 45 instaladas, 5 no disponibles
========================================
```

### Herramientas de Desarrollo (solo target `development`)
- **Symfony CLI**
- **Xdebug** 3.x
- **XHProf** - Profiling
- **PHPDbg** - Debugger

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────┐
│          Imagen Base (Debian)           │
│  Nginx + PHP-FPM 8.3 + Supervisor       │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
┌───────▼────────┐  ┌──────▼─────────┐
│  Development   │  │   Production   │
│  + Xdebug      │  │   Optimizado   │
│  + Symfony CLI │  │   + OPcache    │
└────────────────┘  └────────────────┘
```

---

## 🚀 Uso Rápido

### Con Docker Compose (Recomendado)

1. **Clona o copia este repositorio:**
   ```bash
   git clone <tu-repositorio>
   cd symfony-webapp
   ```

2. **Coloca tu aplicación Symfony en `./webapp/`:**
   ```bash
   # Crear un nuevo proyecto Symfony
   symfony new webapp --webapp
   
   # O copiar uno existente
   cp -r /path/to/tu/app ./webapp/
   ```

3. **Configura las variables de entorno:**
   ```bash
   cp .env .env.local
   # Edita .env.local con tus valores
   ```

4. **Levanta los servicios:**
   ```bash
   # Desarrollo
   docker-compose up -d
   
   # Producción
   COMPOSE_PROFILES=production docker-compose up -d
   ```

5. **Accede a tu aplicación:**
   - **Desarrollo:** http://localhost:8080
   - **Producción:** http://localhost:8081
   - **Mailpit (dev):** http://localhost:8025

---

## 🛠️ Construcción Manual

### Construir imagen de desarrollo
```bash
docker build --target development --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t symfony-dev .
```

### Construir imagen de producción
```bash
docker build --target production -t symfony-prod .
```

### Ejecutar contenedor
```bash
# Desarrollo (monta tu app como volumen)
docker run -d \
  -p 8080:80 \
  -v $(pwd)/mi-app:/var/www/html \
  -e APP_ENV=dev \
  --name symfony-dev \
  symfony-dev

# Producción
docker run -d \
  -p 80:80 \
  -v $(pwd)/mi-app:/var/www/html \
  -e APP_ENV=prod \
  --name symfony-prod \
  symfony-prod
```

---

## 📁 Estructura del Proyecto

```
symfony-webapp/
├── config/
│   ├── nginx-default.conf      # Configuración Nginx
│   ├── supervisord.conf         # Configuración Supervisor
│   ├── php.ini-dev             # PHP config desarrollo
│   └── php.ini-prod            # PHP config producción
├── webapp/                      # ⚠️ MONTA TU APP AQUÍ
│   └── (tu aplicación Symfony)
├── .dockerignore
├── .env                         # Variables de entorno
├── docker-compose.yml           # Orquestación de servicios
├── Dockerfile                   # Multi-stage build
├── entrypoint.sh               # Script de inicialización
└── README.md                    # Este archivo
```

---

## ⚙️ Configuración

### Variables de Entorno Principales

Edita el archivo `.env` con tus valores:

```bash
# Perfil Docker Compose
COMPOSE_PROFILES=development  # o "production"

# Usuario/Grupo (desarrollo)
UID=1000
GID=1000

# Base de datos
DB_HOST=database
DB_DATABASE=myapp
DB_USER=myapp_user
DB_PASSWORD=SecurePassword123

# Symfony
APP_ENV=dev                    # dev | prod | test
APP_DEBUG=1                    # 0 | 1
APP_SECRET=tu_secreto_de_32_caracteres

# Doctrine
DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:5432/${DB_DATABASE}"

# Mailer (Mailpit en dev)
MAILER_DSN=smtp://mailpit:1025
```

### Generar APP_SECRET

```bash
php -r "echo bin2hex(random_bytes(16));"
```

---

## 🔨 Variables de Construcción de Imagen (Build Args)

La imagen Docker acepta variables de construcción que permiten personalizar la configuración durante el **build time**. Estas variables tienen valores por defecto, por lo que son **completamente opcionales**.

### Variables Disponibles

| Variable | Descripción | Valor por Defecto | Ejemplo |
|----------|-------------|-------------------|---------|
| `PHP_VERSION` | Versión de PHP a instalar | `8.3` | `8.2`, `8.3`, `8.4` |
| `LOCALE` | Locale del sistema operativo | `es_ES.UTF-8` | `en_US.UTF-8`, `fr_FR.UTF-8` |
| `TIMEZONE` | Zona horaria del contenedor | `America/Havana` | `America/Mexico_City`, `Europe/Madrid` |
| `UID` | User ID para www-data (solo dev) | `1000` | Tu UID del host |
| `GID` | Group ID para www-data (solo dev) | `1000` | Tu GID del host |

### Uso con Docker CLI

```bash
# Construir con valores por defecto
docker build --target development -t symfony-dev .

# Personalizar versión de PHP
docker build \
  --target production \
  --build-arg PHP_VERSION=8.2 \
  -t symfony-prod:php82 .

# Personalizar múltiples variables
docker build \
  --target development \
  --build-arg PHP_VERSION=8.3 \
  --build-arg LOCALE=en_US.UTF-8 \
  --build-arg TIMEZONE=America/New_York \
  --build-arg UID=$(id -u) \
  --build-arg GID=$(id -g) \
  -t symfony-dev:custom .
```

### Uso con Docker Compose

Edita el archivo `docker-compose.yml` en la sección `build.args`:

```yaml
services:
  dev-server:
    build:
      context: .
      dockerfile: ./Dockerfile
      target: development
      args:
        - UID=${UID:-1000}
        - GID=${GID:-1000}
        # Personalizar versión de PHP
        - PHP_VERSION=8.2
        # Personalizar locale y timezone
        - LOCALE=en_US.UTF-8
        - TIMEZONE=America/New_York
    # ... resto de la configuración
```

O define las variables en tu archivo `.env`:

```bash
# .env
PHP_VERSION=8.3
LOCALE=es_ES.UTF-8
TIMEZONE=America/Havana
UID=1000
GID=1000
```

Y úsalas en `docker-compose.yml`:

```yaml
services:
  dev-server:
    build:
      args:
        - PHP_VERSION=${PHP_VERSION:-8.3}
        - LOCALE=${LOCALE:-es_ES.UTF-8}
        - TIMEZONE=${TIMEZONE:-America/Havana}
        - UID=${UID:-1000}
        - GID=${GID:-1000}
```

Luego construye:

```bash
docker-compose build
# o forzar reconstrucción
docker-compose build --no-cache
```

### Ejemplo: Construir con PHP 8.2 para Europa

```bash
# Línea de comandos
docker build \
  --target production \
  --build-arg PHP_VERSION=8.2 \
  --build-arg LOCALE=es_ES.UTF-8 \
  --build-arg TIMEZONE=Europe/Madrid \
  -t symfony-prod:eu .

# Docker Compose (edita docker-compose.yml)
# build:
#   args:
#     - PHP_VERSION=8.2
#     - LOCALE=es_ES.UTF-8
#     - TIMEZONE=Europe/Madrid

docker-compose build prod-server
```

---

## 🐳 Docker Compose - Servicios Incluidos

| Servicio | Descripción | Puerto | Perfil |
|----------|-------------|--------|--------|
| `dev-server` | Servidor web desarrollo | 8080 | development |
| `prod-server` | Servidor web producción | 8081 | production |
| `db` | PostgreSQL 16 | 5432 | ambos |
| `redis` | Redis 7 Alpine | 6379 | ambos |
| `mailpit` | SMTP testing | 8025 (web)<br>1025 (smtp) | development |

---

## 🔧 Comandos Útiles

### Docker Compose

```bash
# Ver logs
docker-compose logs -f dev-server

# Reconstruir imágenes
docker-compose build --no-cache

# Entrar al contenedor
docker-compose exec dev-server bash

# Parar servicios
docker-compose down

# Limpiar todo (incluye volúmenes)
docker-compose down -v
```

### Symfony CLI (dentro del contenedor)

```bash
# Entrar al contenedor
docker-compose exec dev-server bash

# Comandos Symfony
php bin/console about
php bin/console doctrine:database:create
php bin/console doctrine:migrations:migrate
php bin/console cache:clear

# Con Symfony CLI (solo development)
symfony check:requirements
symfony server:dump  # Ver requests HTTP
```

---

## 🎯 Casos de Uso

### 1. Desarrollo Local

```bash
# Clonar tu proyecto
git clone https://github.com/tu/proyecto.git webapp/

# Levantar servicios
docker-compose up -d

# Instalar dependencias (automático en el primer inicio)
# O manualmente:
docker-compose exec dev-server composer install

# Acceder a la aplicación
open http://localhost:8080
```

### 2. Producción

```bash
# Configurar .env para producción
COMPOSE_PROFILES=production
APP_ENV=prod
APP_DEBUG=0

# Construir y levantar
docker-compose up -d

# Optimizar cache
docker-compose exec prod-server php bin/console cache:warmup
```

### 3. CI/CD (GitLab, GitHub Actions)

```yaml
# .gitlab-ci.yml ejemplo
build:
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build --target production -t myapp:latest .
    - docker push myapp:latest
```

---

## 🔒 Seguridad

### Recomendaciones para Producción

1. **Variables de entorno:** Nunca commitees `.env` con credenciales reales
2. **APP_SECRET:** Genera uno único por proyecto
3. **APP_DEBUG:** Siempre en `0` en producción
4. **Puertos:** No expongas PostgreSQL/Redis públicamente
5. **Actualiza regularmente:** `docker-compose pull && docker-compose up -d`

---

## 🐛 Troubleshooting

### Problema: Permisos en `var/` o `public/`

**Solución:**
```bash
# Ajustar UID/GID en .env para que coincida con tu usuario
id -u  # Obtener tu UID
id -g  # Obtener tu GID

# Reconstruir con los nuevos valores
docker-compose build --no-cache dev-server
```

### Problema: Composer no encuentra dependencias

**Solución:**
```bash
# Limpiar cache de Composer
docker-compose exec dev-server composer clear-cache
docker-compose exec dev-server composer install
```

### Problema: Nginx 502 Bad Gateway

**Solución:**
```bash
# Verificar que PHP-FPM está corriendo
docker-compose exec dev-server supervisorctl status

# Reiniciar servicios
docker-compose restart dev-server
```

---

## 📊 Personalización

### Añadir extensiones PHP adicionales

Edita el `Dockerfile` en la sección de instalación de PHP:

```dockerfile
RUN apt-get update && apt-get install -y \
    php8.3-tu-extension \
    && rm -rf /var/lib/apt/lists/*
```

### Modificar configuración de Nginx

Edita `config/nginx-default.conf` y reconstruye:

```bash
docker-compose build --no-cache
```

### Cambiar versión de PHP

Actualiza todas las referencias de `8.3` a la versión deseada en:
- `Dockerfile`
- `config/nginx-default.conf`
- `config/supervisord.conf`

---

## 📝 Licencia

Este proyecto está bajo licencia MIT. Úsalo libremente en tus proyectos.

---

## 👤 Autor

**Eidy EV**
- Email: eidyev@gmail.com
- GitHub: [@eidyev](https://github.com/eidyev)

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add: AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

## ⭐ ¿Te resulta útil?

Si este proyecto te ayuda, considera darle una estrella ⭐ en GitHub.

---

**Última actualización:** 2025-11-07
