param(
    [string]$PkgDir = (Join-Path $PSScriptRoot "luci-app-nfqws2"),
    [string]$OutDir = (Join-Path $PSScriptRoot "out")
)

$ErrorActionPreference = "Stop"

$PKG_VERSION = "1.0.0"
$PKG_RELEASE = "1"
$PKG_ARCH = "all"

if (-not (Test-Path $PkgDir)) {
    Write-Host "ОШИБКА: Директория пакета не найдена: $PkgDir" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

$TempDir = Join-Path $env:TEMP "ipkg_build_$(Get-Random)"
$InstallRoot = Join-Path $TempDir "ROOT"
$ControlDir = Join-Path $TempDir "CONTROL"

New-Item -ItemType Directory -Path $InstallRoot, $ControlDir | Out-Null

try {
    # --- control ---
    $ControlText = @"
Package: luci-app-nfqws2
Version: ${PKG_VERSION}-${PKG_RELEASE}
Section: luci
Architecture: ${PKG_ARCH}
Maintainer: nfqws2 <nfqws2@example.com>
Source: luci.apps.nfqws2
SourceName: luci-app-nfqws2
Depends: libc, luci-base, curl
Conffiles:
/etc/config/nfqws2
Description: NFQWS2 DPI Bypass Web Interface
 Web interface for managing nfqws2 DPI bypass utility.
"@
    $ControlText | Out-File -FilePath (Join-Path $ControlDir "control") -Encoding UTF8

    # --- data: root/ → корень ---
    $RootSrc = Join-Path $PkgDir "root"
    if (Test-Path $RootSrc) {
        Copy-Item -Recurse -Force (Join-Path $RootSrc "*") $InstallRoot
    }

    # --- data: luasrc/ → /usr/lib/lua/luci/ ---
    $LuaSrc = Join-Path $PkgDir "luasrc"
    if (Test-Path $LuaSrc) {
        $LuaDst = Join-Path $InstallRoot "usr\lib\lua\luci"
        New-Item -ItemType Directory -Path $LuaDst -Force | Out-Null
        Copy-Item -Recurse -Force (Join-Path $LuaSrc "*") $LuaDst
    }

    # --- data: htdocs/ → /www/ ---
    $HtdocsSrc = Join-Path $PkgDir "htdocs"
    if (Test-Path $HtdocsSrc) {
        $HtdocsDst = Join-Path $InstallRoot "www"
        New-Item -ItemType Directory -Path $HtdocsDst -Force | Out-Null
        Copy-Item -Recurse -Force (Join-Path $HtdocsSrc "*") $HtdocsDst
    }

    # --- data: po/ → /usr/lib/lua/luci/i18n/<lang>/ ---
    $PoSrc = Join-Path $PkgDir "po"
    if (Test-Path $PoSrc) {
        Get-ChildItem -Directory $PoSrc | Where-Object { $_.Name -ne "templates" } | ForEach-Object {
            $Lang = $_.Name
            $I18nDir = Join-Path $InstallRoot "usr\lib\lua\luci\i18n\$Lang"
            New-Item -ItemType Directory -Path $I18nDir -Force | Out-Null

            Get-ChildItem -File -Filter "*.po" $_.FullName | ForEach-Object {
                $Base = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                $Dst = Join-Path $I18nDir "${Base}.lmo"
                # Копируем .po → .lmo (утилита po2lmo в OpenWRT сконвертирует при установке,
                # либо конвертируем здесь если po2lmo доступен)
                Copy-Item $_.FullName $Dst
            }
        }
    }

    # Делаем скрипты исполняемыми (chmod не нужен в tar на Windows, но метаданные будут)
    Get-ChildItem -Recurse -File $InstallRoot | Where-Object {
        $_.Extension -in @(".sh", "") -and (
            $_.FullName -match "init\.d" -or $_.FullName -match "share"
        )
    } | ForEach-Object { $_.Mode = "-----x------" }

    # --- Пакетирование ---
    $DataTar = Join-Path $TempDir "data.tar.gz"
    $ControlTar = Join-Path $TempDir "control.tar.gz"
    $SigTar = Join-Path $TempDir "signature.tar.gz"
    $IpkName = "luci-app-nfqws2_${PKG_VERSION}-${PKG_RELEASE}_${PKG_ARCH}.ipk"
    $IpkPath = Join-Path $OutDir $IpkName

    Write-Host "=== Архивация data.tar.gz ===" -ForegroundColor Cyan

    # Используем tar из Windows (встроенный с Win10+)
    Push-Location $InstallRoot
    tar -czf $DataTar .
    Pop-Location

    Write-Host "=== Архивация control.tar.gz ===" -ForegroundColor Cyan
    Push-Location $ControlDir
    tar -czf $ControlTar control
    Pop-Location

    Write-Host "=== Заглушка signature.tar.gz ===" -ForegroundColor Cyan
    Compress-Archive -Path (Join-Path $env:TEMP "dummy_$(Get-Random)") -DestinationPath $SigTar -Force 2>$null; `
    if (-not (Test-Path $SigTar)) {
        # Альтернатива: пустой gz
        [System.IO.File]::WriteAllBytes($SigTar, [byte[]](0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x13, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
    }

    Write-Host "=== Сборка .ipk (ar-архив) ===" -ForegroundColor Cyan

    # ar не доступен на Windows по умолчанию — собираем ipk вручную как tar
    # .ipk — это ar-архив. Альтернатива: tar с префиксами
    # На самом деле opkg понимает ipk как ar, но мы можем собрать через Python:

    $PythonCmd = @"
import struct, os, hashlib, tarfile, io, tempfile

data_tar = r"$DataTar"
control_tar = r"$ControlTar"
sig_tar = r"$SigTar"
ipk_path = r"$IpkPath"

# ar-формат: магический заголовок + записи
MAGIC = b"!<arch>\n"

def ar_header(name, mtime, uid, gid, mode, size):
    name = (name + " ").encode()[:16]
    mtime = str(0).encode().ljust(12)
    uid = b"0       "
    gid = b"0       "
    mode = b"100644  "
    size = str(os.path.getsize(data_tar if name.startswith(b"data") else os.path.getsize(control_tar) if name.startswith(b"control") else 0)).encode().ljust(10)
    return name + mtime + uid + gid + mode + str(size).encode().ljust(10) + b"\n"

# Проще: используем tar напрямую (opkg понимает и tar.gz формат для .ipk)
# Нет, ipk — строго ar. Собираем правильно:

import time

entries = [
    ("control.tar.gz", data_tar if False else control_tar),
    ("data.tar.gz", data_tar),
    ("signature.tar.gz", sig_tar),
]

with open(ipk_path, "wb") as arf:
    arf.write(MAGIC)
    for name, path in entries:
        data = open(path, "rb").read()
        size = len(data)
        header = f"{name} {int(time.time()):012d} 0       0       100644  {size:10d} \n".encode()
        arf.write(header)
        arf.write(data)
        if size % 2 != 0:
            arf.write(b"\n")

print(f"IPK создан: {ipk_path} ({os.path.getsize(ipk_path)} bytes)")
"@

    # Проще — соберём через встроенный Python или используем tar
    # Проверим, есть ли Python:
    $HasPython = $null -ne (Get-Command python -ErrorAction SilentlyContinue)

    if ($HasPython) {
        python -c $PythonCmd
    } else {
        # Fallback: ar через mingw/cygwin/gow
        Write-Host "ОШИБКА: Нужен Python для создания ar-архива (.ipk)" -ForegroundColor Red
        Write-Host "Установите Python или укажите путь к ar (GNU binutils)" -ForegroundColor Yellow
        Remove-Item -Recurse -Force $TempDir
        exit 1
    }

    Write-Host ""
    Write-Host "=== Сборка завершена ===" -ForegroundColor Green
    Write-Host "Путь: $IpkPath" -ForegroundColor Green
    $Size = [math]::Round((Get-Item $IpkPath).Length / 1KB, 1)
    Write-Host "Размер: ${Size} KB" -ForegroundColor Green

} finally {
    Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
}
