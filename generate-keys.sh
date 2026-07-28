#!/bin/bash
# generate-keys.sh — Генерация ключей для подписи APK
# Использует signify/openbsd-signify из OpenWRT SDK

set -e

echo "=== Генерация ключей для подписи APK ==="

# Проверяем наличие signify
if ! command -v signify &> /dev/null && ! command -v signify-openbsd &> /dev/null; then
    echo "ОШИБКА: signify не найден!"
    echo "Установите signify:"
    echo "  Ubuntu: sudo apt-get install signify-openbsd"
    echo "  macOS: brew install signify-openbsd"
    echo "  Или используйте OpenWRT SDK для генерации"
    exit 1
fi

SIGNIFY_CMD="signify"
command -v signify-openbsd &> /dev/null && SIGNIFY_CMD="signify-openbsd"

# Генерируем ключи
echo "Генерация пары ключей..."
$SIGNIFY_CMD -G -n -p public-key.pem -s private-key.pem

echo ""
echo "=== Ключи сгенерированы ==="
echo "Публичный ключ:  public-key.pem"
echo "Приватный ключ:  private-key.pem"
echo ""
echo "=== Инструкции по добавлению в GitHub Secrets ==="
echo ""
echo "1. Перейдите в Settings > Secrets and variables > Actions"
echo "2. Добавьте следующие секреты:"
echo ""
echo "   OPENWRT_APK_PUBLIC_KEY:"
echo "   $(cat public-key.pem)"
echo ""
echo "   OPENWRT_APK_SECRET_KEY:"
echo "   $(cat private-key.pem)"
echo ""
echo "3. Скопируйте публичный ключ на роутер:"
echo "   scp public-key.pem root@<router>:/etc/apk/keys/luci-app-nfqws2.pem"
echo ""
echo "Готово!"
