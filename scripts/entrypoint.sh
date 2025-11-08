#!/bin/bash
set -e

echo "=========================================="
echo "  Symfony Web Server - Entrypoint"
echo "=========================================="

DEFAULT_LOCALE="es_ES.UTF-8"
DEFAULT_TIMEZONE="America/Havana"
DEFAULT_UID="1000"
DEFAULT_GID="1000"

# Locale
if [ -n "$LOCALE" ] && [ "$LOCALE" != "$DEFAULT_LOCALE" ]; then
  echo "→ Configurando locale a $LOCALE"
  sed -i "/${LOCALE}/s/^# //g" /etc/locale.gen
  locale-gen "$LOCALE"
  update-locale LANG="$LOCALE" LC_ALL="$LOCALE"
  export LANG="$LOCALE" LC_ALL="$LOCALE"
fi

# Timezone (Sistema + PHP-FPM + PHP-CLI)
if [ -n "$TIMEZONE" ] && [ "$TIMEZONE" != "$DEFAULT_TIMEZONE" ]; then
  echo "→ Configurando timezone a $TIMEZONE"

  # Sistema
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  echo "$TIMEZONE" > /etc/timezone
  dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1 || true

  # PHP-FPM
  sed -i "s|^;*date.timezone =.*|date.timezone = ${TIMEZONE}|g" /etc/php/${PHP_VERSION}/fpm/php.ini

  # PHP-CLI
  sed -i "s|^;*date.timezone =.*|date.timezone = ${TIMEZONE}|g" /etc/php/${PHP_VERSION}/cli/php.ini
fi

# UID/GID (dev)
if [ "$UID" != "$DEFAULT_UID" ] || [ "$GID" != "$DEFAULT_GID" ]; then
  echo "→ Configurando www-data UID:$UID GID:$GID"
  usermod -u "$UID" www-data 2>/dev/null || true
  groupmod -g "$GID" www-data 2>/dev/null || true
  chown -R www-data:www-data /var/www/html || true
fi

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

  if [ -d "var" ]; then
    chown -R www-data:www-data var && chmod -R 775 var
  fi

  if [ -d "public/uploads" ]; then
    chown -R www-data:www-data public/uploads && chmod -R 775 public/uploads
  fi

  if [ "$APP_ENV" = "prod" ]; then
    echo "→ Cache: clear + warmup (prod)"
    php bin/console cache:clear --env=prod --no-debug || true
    php bin/console cache:warmup --env=prod --no-debug || true
  fi
fi

echo "→ Iniciando servicios con supervisor..."
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &

if [ $# -gt 0 ]; then
  echo "→ Ejecutando comando del usuario: $@"
  exec "$@"
fi

# Mantener contenedor vivo aunque se cierren shells
wait -n
