param(
    [string]$TargetArch = "aarch64",
    [string]$TargetSystem = "armvirt/64",
    [string]$Branch = "openwrt-25.12",
    [switch]$NoCache
)

$ErrorActionPreference = "Stop"
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== Сборка luci-app-nfqws2 для OpenWRT ===" -ForegroundColor Cyan
Write-Host "Архитектура: $TargetArch"
Write-Host "Target: $TargetSystem"
Write-Host "Ветка: $Branch"
Write-Host ""

$PKG_DIR = Join-Path $PSScriptRoot "luci-app-nfqws2"
$BUILD_DIR = Join-Path $PSScriptRoot "build"
$OUT_DIR = Join-Path $PSScriptRoot "out"

if (-not (Test-Path $PKG_DIR)) {
    Write-Host "ОШИБКА: Директория luci-app-nfqws2 не найдена" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $OUT_DIR)) {
    New-Item -ItemType Directory -Path $OUT_DIR | Out-Null
}

if ($NoCache) {
    Write-Host "Удаление кэша сборки..." -ForegroundColor Yellow
    docker system prune -f --volumes
}

Write-Host ""
Write-Host "Шаг 1: Сборка Docker-образа..." -ForegroundColor Cyan
docker build `
    -f (Join-Path $BUILD_DIR "Dockerfile") `
    -t openwrt-builder `
    $BUILD_DIR

Write-Host ""
Write-Host "Шаг 2: Запуск сборки пакета..." -ForegroundColor Cyan
docker run --rm `
    -v "${PKG_DIR}:/pkg/luci-app-nfqws2:ro" `
    -v "${OUT_DIR}:/out" `
    -e TARGET_ARCH=$TargetArch `
    -e TARGET_SYSTEM=$TargetSystem `
    -e JOBS=$(nproc) `
    openwrt-builder

Write-Host ""
if (Get-ChildItem $OUT_DIR -Filter "*.ipk" -ErrorAction SilentlyContinue) {
    Write-Host "=== Сборка завершена ===" -ForegroundColor Green
    Write-Host "Результат:" -ForegroundColor Green
    Get-ChildItem $OUT_DIR -Filter "*.ipk" | ForEach-Object {
        Write-Host "  $($_.FullName) ($([math]::Round($_.Length / 1KB, 1)) KB)"
    }
} else {
    Write-Host "ОШИБКА: .ipk файлы не найдены в $OUT_DIR" -ForegroundColor Red
    exit 1
}
