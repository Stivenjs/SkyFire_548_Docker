#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${SKYFIRE_SOURCE_DIR:-/workspace/source}"
BUILD_DIR="${SKYFIRE_BUILD_DIR:-/workspace/build/docker}"
INSTALL_PREFIX="${SKYFIRE_INSTALL_PREFIX:-/opt/skyfire-server}"
BUILD_JOBS="${BUILD_JOBS:-4}"

echo "==> Configurando SkyFire desde el checkout montado: $SOURCE_DIR"
cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_C_COMPILER=gcc-14 \
    -DCMAKE_CXX_COMPILER=g++-14 \
    -DBOOST_ROOT=/opt/boost_1_91_0 \
    -DOPENSSL_ROOT_DIR=/opt/openssl-4.0.1 \
    -DTOOLS=ON \
    -DAUTH_SERVER=ON \
    -DSCRIPTS=ON \
    -DWITHOUT_GIT=ON

echo "==> Compilando incrementalmente (máximo $BUILD_JOBS trabajos)..."
cmake --build "$BUILD_DIR" --parallel "$BUILD_JOBS"

echo "==> Instalando binarios y plantillas..."
cmake --install "$BUILD_DIR"

exec /usr/local/bin/docker-entrypoint.sh worldserver
