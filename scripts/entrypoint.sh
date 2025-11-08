#!/bin/bash
set -e

echo "=========================================="
echo "  Symfony Web Server - Entrypoint"
echo "=========================================="

DEFAULT_LOCALE=${LOCALE:-es_ES.UTF-8}
DEFAULT_TIMEZONE=${TIMEZONE:-America/Havana}
DEFAULT_UID=${UID:-1000}
DEFAULT_GID=${GID:-1000}

# Locale
if [ -n "$LOCALE" ] && [ "$LOCALE" != "$DEFAULT_LOCALE" ]; then
  echo "→ Configurando locale a $LOCALE"
  sed -i "/${LOCALE}/s/^# //g" /etc/locale.gen
  locale-gen "$LOCALE"
  update-locale LANG="$LOCALE" LC_ALL="$LOCALE"
  export LANG="$LOCALE" LC_ALL="$LOCALE"
fi

# Timezone
if [ -n "$TIMEZONE" ] && [ "$TIMEZONE" != "$DEFAULT_TIMEZONE" ]; then
  echo "→ Configurando timezone a $TIMEZONE"
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  echo "$TIMEZONE" > /etc/timezone
  dpkg-reconfigure -f noninteractive tzdata
fi

# UID/GID (dev)
if [ "$DEFAULT_UID" != "1000" ] || [ "$DEFAULT_GID" != "1000" ]; then
  echo "→ Configurando www-data UID:$DEFAULT_UID GID:$DEFAULT_GID"
  usermod -u "$DEFAULT_UID" www-data 2>/dev/null || true
  groupmod -g "$DEFAULT_GID" www-data 2>/dev/null || true
  chown -R www-data:www-data /var/www/html
fi

# Info PHP
echo -n "→ PHP runtime: "
php -v | head -n1

cd /var/www/html || true

if [ -f "composer.json" ]; then
  echo "✓ Aplicación Symfony detectada"

  if [ ! -d "vendor" ]; then
    echo "→ Instalando dependencias con Composer..."
    if [ "$APP_ENV" = "prod" ]; then
      composer install --no-dev --no-interaction --no-progress --optimize-autoloader
    else
      composer install --no-interaction --no-progress --optimize-autoloader
    fi
    echo "✓ Dependencias instaladas"
  else
    echo "✓ Dependencias ya instaladas (vendor/ encontrado)"
  fi

  # Permisos más seguros (evita 777 en prod)
  if [ -d "var" ]; then
    chown -R www-data:www-data var
    chmod -R 775 var
  fi
  if [ -d "public/uploads" ]; then
    chown -R www-data:www-data public/uploads
    chmod -R 775 public/uploads
  fi

  if [ "$APP_ENV" = "prod" ]; then
    echo "→ Limpiando y calentando caché de producción..."
    php bin/console cache:clear --env=prod --no-debug || true
    php bin/console cache:warmup --env=prod --no-debug || true
  fi
fi

echo "→ Iniciando servicios con supervisor..."
if [ $# -gt 0 ]; then
  exec "$@"
else
  exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
fi
