# Luci-app-nfqws2 — APK Package Build

## Быстрый старт

1. Сгенерировать ключи:
   ```bash
   bash generate-keys.sh
   ```

2. Добавить ключи в GitHub Secrets:
   - `OPENWRT_APK_PUBLIC_KEY` — содержимое `public-key.pem`
   - `OPENWRT_APK_SECRET_KEY` — содержимое `private-key.pem`

3. Запустить сборку в GitHub Actions (вручную или по push)

4. Скачать APK из релизов

## Структура проекта

```
├── .github/workflows/build.yml  — GitHub Actions workflow
├── openwrt/
│   └── luci-app-nfqws2/
│       └── Makefile              — OpenWRT package definition
├── luci-app-nfqws2/             — LuCI application
├── generate-keys.sh             — скрипт генерации ключей
├── VERSION                      — версия пакета
└── README.md                   — этот файл
```

## Требования

- GitHub Actions (бесплатно для публичных репозиториев)
- signify (для генерации ключей)

## Установка на роутер

1. Скопировать публичный ключ на роутер:
   ```bash
   scp public-key.pem root@<router>:/etc/apk/keys/luci-app-nfqws2.pem
   ```

2. Установить APK:
   ```bash
   apk add --allow-untrusted luci-app-nfqws2.apk
   ```

## Обновление версии

Изменить `VERSION` файл и сделать commit. Версия автоматически подхватится в сборке.
