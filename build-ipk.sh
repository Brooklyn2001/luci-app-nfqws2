#!/usr/bin/env bash
# ipkg-build — минимальный аналог для сборки .ipk без OpenWRT SDK
# Используется для пакетов без компиляции C-кода (Lua, shell, данные)

set -e

PKG_DIR="${1:-.}"
PKG_NAME=$(grep '^LUCI_TITLE:=' "$PKG_DIR/Makefile" | sed 's/LUCI_TITLE:=//;s/"//g' | awk '{print $1}' | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
PKG_VERSION="1.0.0"
PKG_RELEASE="1"
PKG_ARCH="${LUCI_PKGARCH:-all}"
INSTALL_DIR=$(mktemp -d)

echo "=== Сборка luci-app-nfqws2-${PKG_VERSION}-${PKG_RELEASE}.${PKG_ARCH}.ipk ==="

# Структура ipk:
# control.tar.gz — DEBIAN/control
# data.tar.gz — содержимое пакета
# signature.tar.gz — пустой (заглушка)

mkdir -p "$INSTALL_DIR/CONTROL"
mkdir -p "$INSTALL_DIR/ROOT"

# Генерируем control
cat > "$INSTALL_DIR/CONTROL/control" <<EOF
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
EOF

# Копируем содержимое пакета (из root/ в корень data)
if [ -d "$PKG_DIR/root" ]; then
    cp -a "$PKG_DIR/root/." "$INSTALL_DIR/ROOT/"
fi

# Копируем luasrc в целевую директорию
if [ -d "$PKG_DIR/luasrc" ]; then
    mkdir -p "$INSTALL_DIR/ROOT/usr/lib/lua/luci"
    cp -a "$PKG_DIR/luasrc/." "$INSTALL_DIR/ROOT/usr/lib/lua/luci/"
fi

# Копируем htdocs (если есть)
if [ -d "$PKG_DIR/htdocs" ]; then
    mkdir -p "$INSTALL_DIR/ROOT/www"
    cp -a "$PKG_DIR/htdocs/." "$INSTALL_DIR/ROOT/www/"
fi

# Копируем po/ →/usr/lib/lua/luci/i18n/
if [ -d "$PKG_DIR/po" ]; then
    for lang_dir in "$PKG_DIR/po"/*/; do
        lang=$(basename "$lang_dir")
        if [ "$lang" = "templates" ]; then continue; fi
        for po_file in "$lang_dir"*.po; do
            [ -f "$po_file" ] || continue
            base=$(basename "$po_file" .po)
            # po → lmo (упрощённо: копируем .po как .lmo)
            mkdir -p "$INSTALL_DIR/ROOT/usr/lib/lua/luci/i18n/${lang}"
            if command -v po2lmo >/dev/null 2>&1; then
                po2lmo "$po_file" "$INSTALL_DIR/ROOT/usr/lib/lua/luci/i18n/${lang}/${base}.lmo"
            else
                # Если po2lmo нет, копируем .po с расширением .lmo (LuCI попробует загрузить)
                cp "$po_file" "$INSTALL_DIR/ROOT/usr/lib/lua/luci/i18n/${lang}/${base}.lmo"
            fi
        done
    done
fi

# Делаем init-скрипт и generate_conf.sh исполняемыми
find "$INSTALL_DIR/ROOT/etc/init.d" -type f -exec chmod 755 {} \;
find "$INSTALL_DIR/ROOT/usr/share" -name "*.sh" -exec chmod 755 {} \;

# Pack data.tar.gz
cd "$INSTALL_DIR/ROOT"
find . -print0 | tar czf "$INSTALL_DIR/data.tar.gz" --null -T -
cd "$INSTALL_DIR"

# Pack control.tar.gz
cd "$INSTALL_DIR/CONTROL"
tar czf "$INSTALL_DIR/control.tar.gz" control
cd "$INSTALL_DIR"

# Пустая подпись
echo "" | gzip > "$INSTALL_DIR/signature.tar.gz"

# Собираем ipk (это просто ar-архив)
IPK_NAME="luci-app-nfqws2_${PKG_VERSION}-${PKG_RELEASE}_${PKG_ARCH}.ipk"
cd "$INSTALL_DIR"
ar rc "$IPK_NAME" control.tar.gz data.tar.gz signature.tar.gz

echo "=== Результат ==="
ls -lh "$INSTALL_DIR/$IPK_NAME"
echo "=== Путь: $INSTALL_DIR/$IPK_NAME ==="
