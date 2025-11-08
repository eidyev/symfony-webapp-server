# --- Dockerfile para servidor web Symfony (nginx + php-fpm + supervisor + composer + symfony-cli) ---

FROM debian:bookworm-slim as base
LABEL maintainer="Eidy EV <eidyev@gmail.com>"

ARG LOCALE=es_ES.UTF-8
ARG TIMEZONE=America/Havana
ARG PHP_VERSION=8.3

ENV LANG=${LOCALE} \
    LC_ALL=${LOCALE} \
    TZ=${TIMEZONE} \
    PHP_VERSION=${PHP_VERSION} \
    DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1

SHELL ["/bin/bash", "-c"]

# Paquetes base
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget unzip ca-certificates gnupg locales tzdata nano mc net-tools dnsutils less lsof zip git jq \
 && sed -i "/${LOCALE}/s/^# //g" /etc/locale.gen && locale-gen ${LOCALE} \
 && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone \
 && rm -rf /var/lib/apt/lists/* /tmp/*

# Repo Sury PHP
RUN wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
 && echo "deb https://packages.sury.org/php bookworm main" > /etc/apt/sources.list.d/php.list

# Nginx, Supervisor, PHP base
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx supervisor \
    php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-common \
 && rm -rf /var/lib/apt/lists/*

# Extensiones PHP (tolerante a indisponibles)
RUN apt-get update && \
    echo "========================================" && \
    echo "Instalando extensiones PHP ${PHP_VERSION}" && \
    echo "========================================" && \
    EXTENSIONS="ctype intl mbstring xml dom simplexml tokenizer yaml \
    sqlite3 mysql pgsql ldap redis memcached igbinary opcache apcu \
    curl gd zip bcmath soap uuid mongodb msgpack oauth swoole exif gmp \
    grpc protobuf odbc bz2 imap smbclient snmp ssh2 lz4 decimal ds vips tidy \
    gnupg enchant inotify mailparse pspell readline http xsl zstd imagick amqp" && \
    INSTALLED=0 && FAILED=0 && \
    for ext in $EXTENSIONS; do \
      PKG="php${PHP_VERSION}-${ext}"; \
      if apt-cache show $PKG >/dev/null 2>&1; then \
        if apt-get install -y --no-install-recommends $PKG 2>/dev/null; then \
          echo "✓ Instalado: $PKG"; INSTALLED=$((INSTALLED+1)); \
        else \
          echo "⚠ No se pudo instalar: $PKG"; FAILED=$((FAILED+1)); \
        fi; \
      else \
        echo "✗ No disponible: $PKG"; FAILED=$((FAILED+1)); \
      fi; \
    done && \
    echo "========================================" && \
    echo "Resumen: $INSTALLED instaladas, $FAILED no disponibles" && \
    rm -rf /var/lib/apt/lists/*

# Composer
RUN curl -sS https://getcomposer.org/installer | php${PHP_VERSION} -- --install-dir=/usr/local/bin --filename=composer

# Supervisord (configuración estándar)
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Estandarizar el socket de PHP-FPM
RUN mkdir -p /run/php && ln -sf /run/php/php${PHP_VERSION}-fpm.sock /run/php/php-fpm.sock


# Estandarizar el ejecutable de PHP-FPM
RUN ln -sf /usr/sbin/php-fpm${PHP_VERSION} /usr/sbin/php-fpm


# Nginx
COPY config/nginx-default.conf /etc/nginx/sites-available/default
RUN rm -f /etc/nginx/sites-enabled/default && ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# PHP-FPM socket dir (si lo usas)
RUN mkdir -p /run/php && chown www-data:www-data /run/php

# App dir
RUN mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html
WORKDIR /var/www/html

# HEALTHCHECK opcional
# HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD curl -fsS http://127.0.0.1/health || exit 1

# ============ DEV ============
FROM base as development
LABEL description="Symfony Web App Server (DEV: Nginx + PHP-FPM ${PHP_VERSION} + Composer + Xdebug)" version="1.0-dev"

ARG UID=1000
ARG GID=1000
RUN if [ "$UID" != "33" ]; then usermod -u $UID www-data && groupmod -g $GID www-data; fi

RUN apt-get update && \
    echo "========================================" && \
    echo "Instalando herramientas de desarrollo PHP ${PHP_VERSION}" && \
    echo "========================================" && \
    DEV_EXTENSIONS="xdebug xhprof phpdbg" && \
    for ext in $DEV_EXTENSIONS; do \
      PKG="php${PHP_VERSION}-${ext}"; \
      if apt-cache show $PKG >/dev/null 2>&1; then apt-get install -y --no-install-recommends $PKG || true; else echo "✗ No disponible: $PKG"; fi; \
    done && \
    rm -rf /var/lib/apt/lists/* /tmp/*

RUN curl -sS https://get.symfony.com/cli/installer | bash && mv /root/.symfony5/bin/symfony /usr/local/bin/symfony

COPY config/php.ini-dev /etc/php/${PHP_VERSION}/fpm/php.ini
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80
STOPSIGNAL SIGTERM
ENTRYPOINT ["entrypoint.sh"]

# ============ PROD ============
FROM base as production
LABEL description="Symfony Web App Server (PROD: Nginx + PHP-FPM ${PHP_VERSION})" version="1.0-prod"

COPY config/php.ini-prod /etc/php/${PHP_VERSION}/fpm/php.ini
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80
STOPSIGNAL SIGTERM
ENTRYPOINT ["entrypoint.sh"]
