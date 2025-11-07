#!/bin/bash

# Termina el script si algún comando falla
set -e

echo "=========================================="
echo "  Symfony Web Server - Entrypoint"
echo "=========================================="

# Nos movemos al directorio de la aplicación web
cd /var/www/html

# Verificar si existe un proyecto Symfony montado
if [ -f "composer.json" ]; then
    echo "✓ Aplicación Symfony detectada"
    
    # Verificamos si la carpeta 'vendor' NO existe
    if [ ! -d "vendor" ]; then
        echo "→ Instalando dependencias con Composer..."
        composer install --no-interaction --no-progress --optimize-autoloader
        echo "✓ Dependencias instaladas"
    else
        echo "✓ Dependencias ya instaladas (vendor/ encontrado)"
    fi
    
    # Asegurar que los permisos son correctos para directorios críticos de Symfony
    if [ -d "var" ]; then
        echo "→ Ajustando permisos en var/..."
        chown -R www-data:www-data var/
    fi
    
    if [ -d "public" ]; then
        echo "→ Ajustando permisos en public/..."
        chown -R www-data:www-data public/
    fi
    
else
    echo "⚠ No se detectó una aplicación Symfony (composer.json no encontrado)"
    echo "⚠ El servidor iniciará pero necesitas montar tu aplicación en /var/www/html"
    echo ""
    echo "Ejemplo:"
    echo "  docker run -v ./mi-app:/var/www/html ..."
    echo ""
fi

echo "=========================================="
echo "→ Iniciando servicios (Nginx + PHP-FPM)..."
echo "=========================================="

# Ejecuta el comando que se pasó al script (será el CMD del Dockerfile)
exec "$@"