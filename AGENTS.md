# coding: utf-8
# Project AGENTS.md — luci-app-nfqws2 OpenWRT package

## Objective
- Сборка и публикация подписанного APK v3 пакета `luci-app-nfqws2` через GitHub Actions с использованием OpenWRT SDK.
- Установка пакета на OpenWRT 25.12.2 (ramips/mt7621, mipsel) роутер через `apk`.

## Important Details
- **Целевая платформа:** OpenWRT 25.12.2 (mipsel_24kc, ramips/mt7621). Используется только `apk` (opkg не доступен).
- **Формат пакета:** APK v3 (ADBd), подпись EC secp256k1 в формате PEM (TraditionalOpenSSL для приватного, SubjectPublicKeyInfo для публичного).
- **Сборка:** GitHub Actions CI, контейнер `openwrt/sdk:x86_64`, пакет как local feed (`src-link`).
- **GitHub репозиторий:** `https://github.com/Brooklyn2001/luci-app-nfqws2`.
- **Доверие на роутере:** публичный ключ должен быть установлен в `/etc/apk/keys/luci-app-nfqws2.pem`.

## Work State
### Completed
- **LuCI приложение:** CBI модели, контроллер, view, init скрипт, генератор конфига — всё готово в `luci-app-nfqws2/`.
- **Структура для OpenWRT:** `openwrt/luci-app-nfqws2/` с `Makefile` и `src/` (содержит `root/`, `luasrc/`, `po/`).
- **CI pipeline:** `.github/workflows/build.yml` — полная сборка, подпись, артефакт, GitHub Release.
- **Ключи подписи:** EC secp256k1, хранились в GitHub Secrets (`OPENWRT_APK_PUBLIC_KEY`, `OPENWRT_APK_SECRET_KEY`).
- **Git:** локальный репозиторий, код запушен в `main`.
- **ЛЛМ файлы:** `AGENTS.md`, `generate_signify_keys.py`, `public-key.pem` удалены из репозитория (остаются локально).

### Active
- **CI билд:** последний запуск — APK найден и собран успешно. Проверить артефакт и GitHub Release.

### Blocked
- **Нет.**

## Next Move
1. Запустить workflow, проверить что APK артефакт создан.
2. Скачать APK с GitHub Releases.
3. Скопировать публичный ключ на роутер: `scp public-key.pem root@router:/etc/apk/keys/luci-app-nfqws2.pem`
4. Установить: `apk add --allow-untrusted luci-app-nfqws2.apk` (или с ключом: `apk add luci-app-nfqws2.apk`).

## Relevant Files
- `.github/workflows/build.yml` — CI pipeline для сборки APK v3.
- `openwrt/luci-app-nfqws2/Makefile` — определение пакета OpenWRT.
- `openwrt/luci-app-nfqws2/src/` — исходники пакета (`root/`, `luasrc/`, `po/`).
- `luci-app-nfqws2/` — исходный код LuCI (Lua, CBI, init скрипты).
- `VERSION` — версия пакета (`1.0.0`).
- `private-key.pem` — приватный ключ (локально, `.gitignore`).
- `public-key.pem` — публичный ключ (локально, для установки на роутер).
