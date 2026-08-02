# luci-app-nfqws2

Web-интерфейс LuCI для управления **[nfqws2](https://github.com/nfqws/nfqws2-keenetic)** — утилитой обхода DPI (Deep Packet Inspection) на роутерах с OpenWRT.

nfqws2 перехватывает трафик через Netfilter NFQUEUE и применяет техники десинхронизации пакетов, позволяя обойти блокировки провайдера. Основное приложение — **[nfqws2-keenetic](https://github.com/nfqws/nfqws2-keenetic)** ([@nfqws](https://github.com/nfqws)), пакет с бинарником, конфигурацией и скриптами запуска.

Этот пакет — **веб-интерфейс** для удобного управления nfqws2 через LuCI: настройка параметров, редактирование списков доменов, просмотр логов, управление службой. Не содержит бинарник nfqws2 — он устанавливается отдельно.

Пакет реализован на **ucode** + чистом HTML/JS, не требует Lua и подходит для **любой архитектуры**.

## Возможности

- **Настройка параметров** — интерфейс, порты, режим работы, стратегии десинхронизации через LuCI
- **Редактор списков доменов** — inline-редактор с проверкой доступности доменов и удалением дубликатов
- **Просмотр логов** — веб-интерфейс для `.log` файлов nfqws2
- **Редактор скриптов** — inline-редактор для скриптов десинхронизации
- **Управление службой** — запуск, остановка, перезапуск и обновление прямо из интерфейса

Доступен в веб-интерфейсе OpenWRT по адресу **Сервисы → NFQWS2**.

## Установка

Скачайте APK с [GitHub Releases](https://github.com/Brooklyn2001/luci-app-nfqws2/releases), скопируйте на роутер и установите:

```bash
scp luci-app-nfqws2.apk root@router:/tmp/
ssh root@router
apk add --allow-untrusted /tmp/luci-app-nfqws2.apk
```

Первый раз используйте `--allow-untrusted`, далее установите публичный ключ:

```bash
scp public-key.pem root@router:/etc/apk/keys/luci-app-nfqws2.pem
apk add /tmp/luci-app-nfqws2.apk
```

## Требования

- OpenWRT 24.10+ / 25.12+ (любая архитектура)
- Пакет **[nfqws2-keenetic](https://github.com/nfqws/nfqws2-keenetic)** (бинарник, конфиги, скрипты)
- Установленные пакеты `luci` и `ucode`

## Обновление

В веб-интерфейсе на странице **Сервисы → NFQWS2 → Настройка** доступна кнопка **Обновить**, которая обновляет пакет nfqws2 через `apk`.

Сам интерфейс обновляется аналогично: скачайте новый APK с Releases и установите:

```bash
apk add /tmp/luci-app-nfqws2.apk
```

## Структура пакета

```
ucode/controller/nfqws2.uc       — маршрутизация и RPC-эндпоинты
root/usr/lib/luci/view/nfqws2/   — HTML/JS view
root/etc/config/nfqws2           — конфигурация UCI по умолчанию
root/etc/init.d/nfqws2           — procd-скрипт службы
root/usr/share/nfqws2/           — генератор конфига и вспомогательные скрипты
```

## Сборка

Пакет собирается автоматически через GitHub Actions при запуске workflow «Build and publish APK». APK подписывается EC secp256k1 ключом и публикуется как GitHub Release.

Для локальной сборки используйте OpenWRT SDK:

```bash
./setup.sh
echo "src-link nfqws2 /path/to/luci-app-nfqws2/openwrt" > feeds.conf
./scripts/feeds update nfqws2
./scripts/feeds install -a -p nfqws2
make defconfig
make package/luci-app-nfqws2/compile V=s
```

Версия пакета задаётся файлом `VERSION`.

## Ссылки

- [nfqws2-keenetic — основное приложение](https://github.com/nfqws/nfqws2-keenetic)
- [zapret — anti-DPI библиотека](https://github.com/bol-van/zapret)
- [Telegram-чат nfqws](https://t.me/nfqws)
- [Issues luci-app-nfqws2](https://github.com/Brooklyn2001/luci-app-nfqws2/issues)
