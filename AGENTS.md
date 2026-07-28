# coding: utf-8
# AGENTS.md — Правила проекта luci-app-nfqws2

## ?? Проект

**LuCI web-интерфейс для nfqws2** — утилита обхода DPI для OpenWRT.
Пакет управляет демоном `nfqws2-keenetic` через UCI-конфигурацию и автоматически генерирует `nfqws2.conf` при старте сервиса.

**Целевая платформа:** OpenWRT 25.12+ (apk-tools 3.0+, формат APK v3/ADBd)
**Архитектура:** mipsel_24kc (ramips/mt7621), универсальный (`all`)

---

## ?? Структура проекта

```
nfqws2-openwrt/
├── .github/workflows/build.yml   ← GitHub Actions: сборка APK через OpenWRT SDK
├── luci-app-nfqws2/              ← OpenWRT LuCI пакет
│   ├── Makefile                  ← стандартный LuCI Makefile
│   ├── luasrc/
│   │   ├── controller/nfqws2.lua ← маршруты + RPC-эндпоинты
│   │   └── model/cbi/nfqws2/     ← CBI-модели (формы LuCI)
│   │       ├── config.lua        ← основные настройки + стратегии
│   │       ├── lists.lua         ← редактор списков доменов/IP
│   │       ├── logs.lua          ← просмотр логов
│   │       └── scripts.lua       ← редактор Lua-скриптов
│   ├── po/                       ← локализация
│   └── root/                     ← файлы, устанавливаемые на роутер
│       ├── etc/config/nfqws2     ← UCI-конфиг по умолчанию
│       ├── etc/init.d/nfqws2     ← проcd init-скрипт
│       └── usr/share/nfqws2/
│           └── generate_conf.sh  ← генерация nfqws2.conf из UCI
├── openwrt/
│   └── luci-app-nfqws2/
│       └── Makefile              ← OpenWRT SDK package definition
├── VERSION                       ← версия пакета (1.0.0)
├── generate-keys.sh              ← генерация signify-ключей для APK
└── README.md                     ← инструкции
```

---

## ?? Технологии

| Слој          | Технология                          |
|---------------|-------------------------------------|
| Web-интерфейс | LuCI CBI (Lua 5.4, OpenWRT API)    |
| Конфиг        | UCI (`/etc/config/nfqws2`)          |
| Сервис        | procd (`/etc/init.d/nfqws2`)        |
| Генерация конф.| Shell (`generate_conf.sh`)          |
| Сборка        | OpenWRT SDK + GitHub Actions        |
| Пакетный формат| APK v3 (ADBd), signify/Ed25519     |

---

## ?? Lua / LuCI правила

1. **Кодировка:** UTF-8
2. **Отступы:** таб (табуляция), как в соседних файлах
3. **Стиль:** Lua 5.4, совместимость с OpenWRT LuCI
4. **Переводы:** все строки UI через `translate("...")`
5. **Безопасность:**
   - Валидировать все входные данные от пользователя
   - Использовать `luci.http.formvalue()` с проверками
   - Не выполнять произвольные команды без валидации
   - Пути файлов — строго по типу (.list, .lua, .conf, .log)
6. **RPC-эндпоинты:** формат `action_<name>()`, ответ через `json_response()`

---

## ?? Shell-скрипты

1. **Синтаксис:** POSIX sh (`#!/bin/sh`)
2. **UCI:** только `uci get/set`, без прямых правок файлов
3. **Инициализация:** procd формат (`USE_PROCD=1`)
4. **Генерация конфига:** `generate_conf.sh` читает UCI → пишет `/etc/nfqws2/nfqws2.conf`

---

## ?? OpenWRT пакетирование

1. **Makefile (SDK):** `openwrt/luci-app-nfqws2/Makefile`
   - Читает версию из `../../VERSION`
   - Копирует файлы из `luci-app-nfqws2/root/` в пакет
2. **Зависимости:** `+luci-base +curl` (nfqws2-keenetic устанавливается отдельно)
3. **Conffiles:** `/etc/config/nfqws2`

---

## ?? Сборка APK (GitHub Actions)

```bash
# Локальная генерация ключей (требует signify/signify-openbsd)
bash generate-keys.sh

# Добавить в GitHub Secrets:
#   OPENWRT_APK_PUBLIC_KEY  ← содержимое public-key.pem
#   OPENWRT_APK_SECRET_KEY  ← содержимое private-key.pem

# Запуск в GitHub Actions → Actions → "Build and publish APK" → Run workflow
```

**Workflow:** `.github/workflows/build.yml`
- Контейнер: `openwrt/sdk:x86_64`
- Компиляция: `make CONFIG_USE_APK=y package/luci-app-nfqws2/compile`
- Результат: APK v3 в Releases

---

## ?? UCI-конфигурация

**Секция `general`:**
| Параметр          | Тип     | Описание                          |
|-------------------|---------|-----------------------------------|
| enabled           | flag    | Включить сервис                   |
| isp_interface     | string  | Сетевой интерфейс провайдера      |
| tcp_ports         | string  | TCP-порты для обработки           |
| udp_ports         | string  | UDP-порты для обработки           |
| ipv6_enabled      | flag    | Обработка IPv6                    |
| policy_name       | string  | Название Keenetic policy          |
| policy_exclude    | flag    | Инвертировать policy              |
| nfqueue_num       | string  | Номер NFQueue                     |
| user              | string  | Пользователь для запуска          |
| log_level         | flag    | Debug-логирование                 |
| nfqws_mode        | list    | MODE_AUTO / MODE_LIST / MODE_ALL  |

**Секция `strategies`:**
| Параметр           | Тип      | Описание                      |
|--------------------|----------|-------------------------------|
| nfqws_base_args    | text     | Базовые аргументы запуска     |
| nfqws_args         | text     | Стратегия HTTPS/HTTP          |
| nfqws_args_quic    | text     | Стратегия QUIC                |
| nfqws_args_udp     | text     | Стратегия UDP                 |
| nfqws_args_custom  | text     | Пользовательские стратегии    |
| nfqws_args_ipset   | text     | Аргументы IPSET               |

---

## ?? Запреты

- **Никогда** не коммитьте приватные ключи (`private-key.pem`, `.keys/`)
- Не модифицируйте файлы в `out/` — это артефакты сборки
- Не используйте `eval()` в Lua
- Не хардкодите пути — используйте переменные из UCI

---

## ?? Команды

```bash
# Просмотр UCI-конфига на роутере
uci show nfqws2

# Перезапуск сервиса
/etc/init.d/nfqws2 restart

# Просмотр сгенерированного конфига
cat /etc/nfqws2/nfqws2.conf

# Логи
logread | grep nfqws2
```
