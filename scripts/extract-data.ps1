# SkyFire 5.4.8 - Script de Extracción de Datos
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   SkyFire 5.4.8 - Extractor de Mapas y Datos (WoW)     " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Ejecutar extractor asegurando aislamiento total (--no-deps)
docker compose --profile tools run --rm --no-deps extractor

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "   Proceso finalizado.                                  " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
