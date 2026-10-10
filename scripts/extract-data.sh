#!/usr/bin/env bash
set -e

# SkyFire 5.4.8 - Script de Extracción de Datos (Linux / macOS / WSL)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "========================================================"
echo "   SkyFire 5.4.8 - Extractor de Mapas y Datos (WoW)     "
echo "========================================================"
echo ""

# Ejecutar extractor asegurando aislamiento total (--no-deps)
docker compose --profile tools run --rm --no-deps extractor

echo ""
echo "========================================================"
echo "   Proceso finalizado.                                  "
echo "========================================================"
