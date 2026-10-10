@echo off
setlocal
title SkyFire 5.4.8 - Extractor de Datos

echo ========================================================
echo    SkyFire 5.4.8 - Extractor de Mapas y Datos (WoW)
echo ========================================================
echo.

:: Cambiar al directorio raiz del proyecto
cd /d "%~dp0\.."

:: Ejecutar extractor asegurando aislamiento total (--no-deps)
docker compose --profile tools run --rm --no-deps extractor

echo.
echo ========================================================
echo    Proceso finalizado.
echo ========================================================
pause
