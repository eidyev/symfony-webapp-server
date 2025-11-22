#!/bin/bash
set -e

IMAGE_NAME="eidyev/symfony-webapp-server"
PLATFORMS="linux/amd64,linux/arm64"
VERSIONS=("8.0" "8.1" "8.2" "8.3" "8.4")

NO_PUSH=0

# ===============================
#  Parseo de parámetros
# ===============================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-push)
      NO_PUSH=1
      shift
      ;;
    -h|--help)
      echo "Uso: $0 [--no-push]"
      echo
      echo "  sin parámetros   -> build multi-arch (+ push a Docker Hub)"
      echo "  --no-push        -> build solo para la arquitectura local, sin push (usa --load)"
      exit 0
      ;;
    *)
      echo "Parámetro no reconocido: $1"
      echo "Uso: $0 [--no-push]"
      exit 1
      ;;
  esac
done

# ===============================
#  Config según modo (push / no-push)
# ===============================
if [ "$NO_PUSH" -eq 1 ]; then
  # Detectar arquitectura local para usar --load correctamente
  HOST_ARCH="$(uname -m)"
  case "$HOST_ARCH" in
    x86_64|amd64)
      LOCAL_PLATFORM="linux/amd64"
      ;;
    aarch64|arm64)
      LOCAL_PLATFORM="linux/arm64"
      ;;
    *)
      echo "⚠ Arquitectura local '$HOST_ARCH' no reconocida, usando linux/amd64 por defecto"
      LOCAL_PLATFORM="linux/amd64"
      ;;
  esac

  PLATFORM_ARG="$LOCAL_PLATFORM"
  OUTPUT_MODE="--load"
  MODE_LABEL="(SOLO BUILD LOCAL, SIN PUSH)"
else
  PLATFORM_ARG="$PLATFORMS"
  OUTPUT_MODE="--push"
  MODE_LABEL="(BUILD + PUSH MULTI-ARCH)"
fi

echo "=========================================="
echo "  Building Images $MODE_LABEL"
echo "  Image: $IMAGE_NAME"
echo "  Plataformas: $PLATFORM_ARG"
echo "=========================================="

# Asegurar buildx
docker buildx create --use --name multiarch >/dev/null 2>&1 || true
docker buildx inspect --bootstrap >/dev/null 2>&1 || true

# ===============================
#  Build por versiones
# ===============================
for VERSION in "${VERSIONS[@]}"; do
  echo ""
  echo "------------------------------------------"
  echo "  Building PHP ${VERSION} (DEV)"
  echo "------------------------------------------"

  docker buildx build \
    --platform "$PLATFORM_ARG" \
    --build-arg PHP_VERSION="$VERSION" \
    --target development \
    -t "$IMAGE_NAME:php-$VERSION-dev" \
    $OUTPUT_MODE .

  echo ""
  echo "------------------------------------------"
  echo "  Building PHP ${VERSION} (PROD)"
  echo "------------------------------------------"

  docker buildx build \
    --platform "$PLATFORM_ARG" \
    --build-arg PHP_VERSION="$VERSION" \
    --target production \
    -t "$IMAGE_NAME:php-$VERSION-prod" \
    $OUTPUT_MODE .
done

# ===============================
#  Tag latest (basado en 8.4)
# ===============================
echo ""
echo "=========================================="
echo "   Tagging latest (based on 8.4)"
echo "=========================================="

docker buildx build \
  --platform "$PLATFORM_ARG" \
  --build-arg PHP_VERSION=8.4 \
  --target development \
  -t "$IMAGE_NAME:latest-dev" \
  $OUTPUT_MODE .

docker buildx build \
  --platform "$PLATFORM_ARG" \
  --build-arg PHP_VERSION=8.4 \
  --target production \
  -t "$IMAGE_NAME:latest-prod" \
  -t "$IMAGE_NAME:latest" \
  $OUTPUT_MODE .

echo ""
echo "=========================================="

if [ "$NO_PUSH" -eq 1 ]; then
  echo "✅ DONE! Imágenes construidas y cargadas en Docker local (sin push)"
  echo ""
  echo "  Puedes verlas con: docker images '$IMAGE_NAME'"
  echo "  Y subir las que quieras manualmente, por ejemplo:"
  echo "    docker push $IMAGE_NAME:php-8.4-dev"
else
  echo "✅ DONE! Multi-arch images publicadas en Docker Hub:"
  echo ""
  echo "  DEV : $IMAGE_NAME:php-8.X-dev  + latest-dev"
  echo "  PROD: $IMAGE_NAME:php-8.X-prod + latest-prod + latest"
fi

echo "=========================================="
