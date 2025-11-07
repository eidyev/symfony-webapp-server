# --- Dockerfile para construcción de imágenes de servidor web para Symfony (nginx + php8.3-fpm + supervisor + composer +symfony-cli.)---

# =================================================================
# Etapa BASE: Contiene lo que es común para DEV y PROD
# =================================================================
FROM debian:bookworm-slim as base

LABEL maintainer="Eidy EV <eidyev@gmail.com>"

# Build arguments con valores por defecto (configurables en build time)
ARG LOCALE=es_ES.UTF-8
ARG TIMEZONE=America/Havana
ARG PHP_VERSION=8.3

# Variables de entorno runtime
ENV LANG=${LOCALE} \
    LC_ALL=${LOCALE} \
    TZ=${TIMEZONE} \
    PHP_VERSION=${PHP_VERSION} \
    DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-c"]

# Instalar dependencias base + locales + herramientas de utilidades y diagnostico
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash curl wget unzip ca-certificates gnupg locales tzdata nano mc net-tools dnsutils less lsof zip git jq && \
    sed -i "/${LOCALE}/s/^# //g" /etc/locale.gen && locale-gen ${LOCALE} && \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone && \
    rm -rf /var/lib/apt/lists/* /tmp/*

# Agregar repositorio de Sury para PHP
RUN wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php bookworm main" > /etc/apt/sources.list.d/php.list

# Instalar Nginx, Supervisor y PHP base
RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx supervisor \
        php${PHP_VERSION} \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-common \
    && rm -rf /var/lib/apt/lists/*

# Instalar extensiones PHP (con manejo de errores - no falla si alguna no existe)
RUN apt-get update && \
    echo "========================================" && \
    echo "Instalando extensiones PHP ${PHP_VERSION}" && \
    echo "========================================" && \
    EXTENSIONS=" \
        ctype intl mbstring xml dom simplexml tokenizer yaml \
        sqlite3 mysql pgsql ldap \
        redis memcached igbinary \
        opcache apcu \
        curl gd zip \
        bcmath soap uuid \
        mongodb msgpack \
        oauth swoole exif gmp \
        grpc protobuf \
        odbc bz2 imap \
        smbclient snmp ssh2 \
        lz4 decimal ds vips tidy \
        gnupg enchant inotify mailparse \
        pspell readline http xsl zstd \
        imagick amqp \
    " && \
    INSTALLED=0 && \
    FAILED=0 && \
    for ext in $EXTENSIONS; do \
        PKG="php${PHP_VERSION}-${ext}"; \
        if apt-cache show $PKG >/dev/null 2>&1; then \
            if apt-get install -y --no-install-recommends $PKG 2>/dev/null; then \
                echo "✓ Instalado: $PKG"; \
                INSTALLED=$((INSTALLED + 1)); \
            else \
                echo "⚠ No se pudo instalar: $PKG"; \
                FAILED=$((FAILED + 1)); \
            fi; \
        else \
            echo "✗ No disponible: $PKG"; \
            FAILED=$((FAILED + 1)); \
        fi; \
    done && \
    echo "========================================" && \
    echo "Resumen: $INSTALLED instaladas, $FAILED no disponibles" && \
    echo "========================================" && \
    rm -rf /var/lib/apt/lists/*

# Instalar Composer
RUN curl -sS https://getcomposer.org/installer | php${PHP_VERSION} -- --install-dir=/usr/local/bin --filename=composer

# Configurar Supervisord para arrancar los servicios
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Configurar Nginx
COPY config/nginx-default.conf /etc/nginx/sites-available/default

# Habilitar el sitio en Nginx
RUN rm /etc/nginx/sites-enabled/default && ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Preparar directorio web
RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html
WORKDIR /var/www/html



# =================================================================
# Etapa DEVELOPMENT: Construida a partir de 'base'
# =================================================================
FROM base as development

LABEL description="Web App Server (DEV: Nginx + PHP-FPM ${PHP_VERSION} + Composer + Xdebug)" version="1.0-dev"

# Build arguments para usuario (con valores por defecto)
ARG UID=1000
ARG GID=1000

# Crea el usuario con los IDs recibidos si es necesario o los modifica
RUN if [ "$UID" != "33" ]; then usermod -u $UID www-data && groupmod -g $GID www-data; fi

# Instalar Xdebug y herramientas de desarrollo (con manejo de errores)
RUN apt-get update && \
    echo "========================================" && \
    echo "Instalando herramientas de desarrollo PHP ${PHP_VERSION}" && \
    echo "========================================" && \
    DEV_EXTENSIONS="xdebug xhprof phpdbg" && \
    for ext in $DEV_EXTENSIONS; do \
        PKG="php${PHP_VERSION}-${ext}"; \
        if apt-cache show $PKG >/dev/null 2>&1; then \
            if apt-get install -y --no-install-recommends $PKG 2>/dev/null; then \
                echo "✓ Instalado: $PKG"; \
            else \
                echo "⚠ No se pudo instalar: $PKG"; \
            fi; \
        else \
            echo "✗ No disponible: $PKG"; \
        fi; \
    done && \
    echo "========================================" && \
    rm -rf /var/lib/apt/lists/* /tmp/*

# Instalar el Symfony CLI
RUN curl -sS https://get.symfony.com/cli/installer | bash && mv /root/.symfony5/bin/symfony /usr/local/bin/symfony

COPY config/php.ini-dev /etc/php/${PHP_VERSION}/fpm/php.ini

# Copiamos el entrypoint (sigue siendo útil en desarrollo)
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80
ENTRYPOINT ["entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# =================================================================
# Etapa PRODUCTION: También construida a partir de 'base'
# =================================================================
FROM base as production
LABEL description="Web App Server (PROD: Nginx + PHP-FPM ${PHP_VERSION})" version="1.0-prod"

# Copiamos las configuraciones de producción
COPY config/php.ini-prod /etc/php/${PHP_VERSION}/fpm/php.ini

# Copiamos el entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

# Crear el directorio y asegurar permisos para www-data
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80
ENTRYPOINT ["entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]