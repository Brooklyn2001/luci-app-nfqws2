# Установка luci-app-nfqws2 вручную на OpenWRT 25.12
# Скопируйте этот скрипт на роутер и запустите:
#   scp install.sh root@OpenWrt:/tmp/
#   scp luci-app-nfqws2_1.0.0-1_all.apk root@OpenWrt:/tmp/
#   ssh root@OpenWrt "sh /tmp/install.sh"

#!/bin/sh
set -e

APK="/tmp/luci-app-nfqws2_1.0.0-1_all.apk"

if [ ! -f "$APK" ]; then
    echo "ОШИБКА: $APK не найдена"
    exit 1
fi

echo "=== Установка luci-app-nfqws2 ==="

# Распаковываем, пропуская .SIGN.RSA, .PKGINFO, .DIRMD5
tar -xzf "$APK" -C / --exclude='.SIGN.RSA' --exclude='.PKGINFO' --exclude='.DIRMD5'

# Права на скрипты
chmod 755 /etc/init.d/nfqws2
chmod 755 /usr/share/nfqws2/generate_conf.sh

# Генерируем nfqws2.conf из UCI
if [ -x /usr/share/nfqws2/generate_conf.sh ]; then
    /usr/share/nfqws2/generate_conf.sh
    echo "nfqws2.conf сгенерирован"
fi

# Перезагружаем LuCI (перечитывает меню)
/etc/init.d/uhttpd restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || true

echo ""
echo "=== Установка завершена ==="
echo "Перейдите: Службы -> NFQWS2 в веб-интерфейсе LuCI"
echo ""
echo "Для запуска службы:"
echo "  /etc/init.d/nfqws2 enable"
echo "  /etc/init.d/nfqws2 start"
