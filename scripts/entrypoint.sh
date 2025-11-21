#!/bin/bash
set -e

echo "=========================================="
echo "  Symfony Web Server - Entrypoint"
echo "=========================================="

# -----------------------------
# Valores por defecto
# -----------------------------
DEFAULT_LOCALE="es_ES.UTF-8"
DEFAULT_TIMEZONE="America/Havana"
DEFAULT_UID="1000"
DEFAULT_GID="1000"

# Directorio de la app dentro del contenedor
APP_DIR="${APP_DIR:-/var/www/html}"

# =====================================================
# 1) SETEO DE PARÁMETROS POR VARIABLES DE ENTORNO
#    - UID / GID / permisos
#    - LOCALE
#    - TIMEZONE
# =====================================================

# Ajustar UID/GID de www-data
if [ "${UID:-$DEFAULT_UID}" != "$DEFAULT_UID" ] || [ "${GID:-$DEFAULT_GID}" != "$DEFAULT_GID" ]; then
  echo "→ Configurando www-data UID:${UID:-$DEFAULT_UID} GID:${GID:-$DEFAULT_GID}"
  usermod -u "${UID:-$DEFAULT_UID}" www-data 2>/dev/null || true
  groupmod -g "${GID:-$DEFAULT_GID}" www-data 2>/dev/null || true
fi

# Dar permisos a www-data sobre la app
chown -R www-data:www-data "$APP_DIR" 2>/dev/null || true

# Locale
if [ -n "${LOCALE:-}" ] && [ "$LOCALE" != "$DEFAULT_LOCALE" ]; then
  echo "→ Configurando locale a $LOCALE"
  sed -i "/${LOCALE}/s/^# //g" /etc/locale.gen || true
  locale-gen "$LOCALE" || true
  update-locale LANG="$LOCALE" LC_ALL="$LOCALE" || true
  export LANG="$LOCALE" LC_ALL="$LOCALE"
fi

# Timezone (Sistema + PHP-FPM + PHP-CLI)
if [ -n "${TIMEZONE:-}" ] && [ "$TIMEZONE" != "$DEFAULT_TIMEZONE" ]; then
  echo "→ Configurando timezone a $TIMEZONE"

  # Sistema
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  echo "$TIMEZONE" > /etc/timezone
  dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1 || true

  # PHP-FPM
  sed -i "s|^;*date.timezone =.*|date.timezone = ${TIMEZONE}|g" /etc/php/${PHP_VERSION}/fpm/php.ini || true

  # PHP-CLI
  sed -i "s|^;*date.timezone =.*|date.timezone = ${TIMEZONE}|g" /etc/php/${PHP_VERSION}/cli/php.ini || true
fi

# =====================================================
# 2) CONFIG DE deploy/ Y UTILIDADES
# =====================================================

DEPLOY_DIR="${DEPLOY_DIR:-$APP_DIR/deploy}"
STATE_DIR_DEFAULT="$DEPLOY_DIR/state"

FIRSTRUN_CMDS_DEFAULT="$DEPLOY_DIR/firstrun.cmds"
UPDTRUN_CMDS_DEFAULT="$DEPLOY_DIR/updtrun.cmds"
APP_VERSION_FILE_DEFAULT="$DEPLOY_DIR/version"

FIRST_RUN_FLAG_DEFAULT="$STATE_DIR_DEFAULT/.first-run-complete"
LAST_VERSION_FILE_DEFAULT="$STATE_DIR_DEFAULT/.last-version"
DEPLOY_LOG_FILE_DEFAULT="$DEPLOY_DIR/deploy.log"

STATE_DIR="${DEPLOY_STATE_DIR:-$STATE_DIR_DEFAULT}"
FIRSTRUN_CMDS="${FIRSTRUN_CMDS:-$FIRSTRUN_CMDS_DEFAULT}"
UPDTRUN_CMDS="${UPDTRUN_CMDS:-$UPDTRUN_CMDS_DEFAULT}"
APP_VERSION_FILE="${APP_VERSION_FILE:-$APP_VERSION_FILE_DEFAULT}"
FIRST_RUN_FLAG="${FIRST_RUN_FLAG:-$FIRST_RUN_FLAG_DEFAULT}"
LAST_VERSION_FILE="${LAST_VERSION_FILE:-$LAST_VERSION_FILE_DEFAULT}"
DEPLOY_LOG_FILE="${DEPLOY_LOG_FILE:-$DEPLOY_LOG_FILE_DEFAULT}"

DEPLOY_ENABLED=0
if [ -d "$DEPLOY_DIR" ]; then
    DEPLOY_ENABLED=1
    mkdir -p "$STATE_DIR"
    touch "$DEPLOY_LOG_FILE" 2>/dev/null || true
fi

# Función de log
log() {
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] [entrypoint] $msg"
    if [ "$DEPLOY_ENABLED" -eq 1 ]; then
        echo "[$ts] [entrypoint] $msg" >> "$DEPLOY_LOG_FILE" 2>/dev/null || true
    fi
}

# Leer versión desde archivo
read_version_file() {
    local file="$1"
    if [ -f "$file" ]; then
        tr -d '\r' < "$file" | head -n1
    else
        echo ""
    fi
}

# Ejecutar comandos de un .cmds
run_cmds_file() {
    local file="$1"
    local label="$2"

    if [ ! -f "$file" ]; then
        log "[$label] Archivo $file no encontrado, nada que ejecutar."
        return 0
    fi

    log "[$label] Ejecutando comandos desde $file"
    cd "$APP_DIR"

    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^# ]] && continue

        log "[$label] -> $line"
        # Ejecutar siempre como www-data
        su -s /bin/bash www-data -c "$line"
    done < "$file"
}

run_first_time_setup() {
    log "🚀 Running first-time setup..."

    run_cmds_file "$FIRSTRUN_CMDS" "first-run"

    local CURRENT_VERSION
    CURRENT_VERSION="$(read_version_file "$APP_VERSION_FILE")"
    if [ -n "$CURRENT_VERSION" ]; then
        echo "$CURRENT_VERSION" > "$LAST_VERSION_FILE"
        log "[first-run] Versión inicial aplicada: $CURRENT_VERSION"
    else
        log "[first-run] No se encontró archivo de versión en $APP_VERSION_FILE"
    fi

    touch "$FIRST_RUN_FLAG"
}

run_updates() {
    log "🔄 Running application updates..."

    run_cmds_file "$UPDTRUN_CMDS" "update"

    local CURRENT_VERSION
    CURRENT_VERSION="$(read_version_file "$APP_VERSION_FILE")"
    if [ -n "$CURRENT_VERSION" ]; then
        echo "$CURRENT_VERSION" > "$LAST_VERSION_FILE"
        log "[update] Versión actualizada a: $CURRENT_VERSION"
    else
        log "[update] No se encontró archivo de versión en $APP_VERSION_FILE"
    fi
}

# =====================================================
# 3) LÓGICA PRINCIPAL DE deploy/
#    - Primera vez: SOLO firstrun
#    - Siguientes veces: SOLO update si cambia la versión
# =====================================================

# Modo explícito (forzado)
if [ "${1:-}" = "first-run" ] || [ "${RUN_MODE:-}" = "first-run" ]; then
    if [ "$DEPLOY_ENABLED" -eq 1 ]; then
        run_first_time_setup
    else
        log "RUN_MODE=first-run pero deploy/ no existe. Nada que hacer."
    fi
    exit 0
elif [ "${1:-}" = "update" ] || [ "${RUN_MODE:-}" = "update" ]; then
    if [ "$DEPLOY_ENABLED" -eq 1 ]; then
        run_updates
    else
        log "RUN_MODE=update pero deploy/ no existe. Nada que hacer."
    fi
    exit 0
fi

if [ "$DEPLOY_ENABLED" -eq 1 ]; then
    CURRENT_VERSION="$(read_version_file "$APP_VERSION_FILE")"
    LAST_VERSION=""
    if [ -f "$LAST_VERSION_FILE" ]; then
        LAST_VERSION="$(cat "$LAST_VERSION_FILE")"
    fi

    # Primera vez: solo firstrun, nunca update aquí
    if [ ! -f "$FIRST_RUN_FLAG" ]; then
        log "Primer arranque detectado (deploy/ habilitado, no existe $FIRST_RUN_FLAG)"
        run_first_time_setup
    else
        # Ya no es primera vez: ahora sí se permite update si cambia la versión
        if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "$LAST_VERSION" ]; then
            log "📦 Versión nueva detectada: '$LAST_VERSION' → '$CURRENT_VERSION'"
            run_updates
        else
            log "✅ Sin cambios de versión o sin archivo de versión, no se ejecuta update."
        fi
    fi
else
    # deploy/ es opcional, si no existe no se hace nada especial
    echo "[entrypoint] deploy/ no existe, se omite lógica de firstrun/update y versión."
fi

# =====================================================
# 4) INFO PHP Y LÓGICA SYMFONY GENÉRICA
# =====================================================

echo -n "→ PHP runtime: "
php -v | head -n1

cd "$APP_DIR" || true

# Lógica Symfony genérica (opcional)
if [ -f "composer.json" ] && [ "${DISABLE_AUTO_COMPOSER:-false}" != "true" ]; then
  log "✓ Aplicación Symfony detectada"

  if [ ! -d "vendor" ]; then
    log "→ Instalando dependencias con Composer..."
    if [ "${APP_ENV:-dev}" = "prod" ]; then
      composer install --no-dev --no-interaction --no-progress --optimize-autoloader
    else
      composer install --no-interaction --no-progress --optimize-autoloader
    fi
    log "✓ Dependencias instaladas"
  else
    log "✓ Dependencias ya instaladas (vendor/ encontrado)"
  fi

  if [ -d "var" ]; then
    chown -R www-data:www-data var && chmod -R 775 var || true
  fi

  if [ -d "public/uploads" ]; then
    chown -R www-data:www-data public/uploads && chmod -R 775 public/uploads || true
  fi

  if [ "${APP_ENV:-dev}" = "prod" ]; then
    log "→ Cache: clear + warmup (prod)"
    php bin/console cache:clear --env=prod --no-debug || true
    php bin/console cache:warmup --env=prod --no-debug || true
  fi
fi

# =====================================================
# 5) LANZAR SUPERVISOR
# =====================================================

log "→ Iniciando servicios con supervisor..."
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &

if [ $# -gt 0 ]; then
  log "→ Ejecutando comando del usuario: $*"
  exec "$@"
fi

wait -n
