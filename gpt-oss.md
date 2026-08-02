**Кратко:**  
Ошибка  

```
ERROR: wget: exited with error 8
ERROR: luci-app-nfqws2-1.0.0-r1: unexpected end of file
```

появляется **не при скачивании исходников** (вы уже проверили, что URL работает), а **при попытке apk распаковать уже собранный .apk‑файл**.  
`apk` считает, что внутри пакета обрезан архив `data.tar.gz` (или `data.tar.xz`), поэтому завершается с “unexpected end of file”.

Ниже – пошаговое руководство, как определить, что именно повреждено, и как собрать корректный пакет, чтобы установка прошла без ошибок.

---

## 1. Что именно проверяет `apk` при установке

Формат пакета **APK** (Alpine Linux) – это обычный `ar`‑архив, содержащий три части:

```
ar t <pkg>.apk
# → debian-binary
# → control.tar.gz
# → data.tar.gz   (или data.tar.xz)
```

* `debian-binary` – просто строка «2.0».
* `control.tar.gz` – метаданные (контрольный файл, скрипты pre/post‑install и т.п.).
* **`data.tar.gz`** – собственно файлы, которые будут распакованы в корень файловой системы (`/usr`, `/etc`, …).

Если `data.tar.gz` повреждён (обрезан, пустой, не‑gzip), `apk` выдаёт именно сообщение  
`unexpected end of file` на этапе распаковки этого архива.

---

## 2. Как быстро проверить, какой именно файл плох

Скачайте полученный `.apk` из вашего репозитория (или локально из каталога `packages/`) и выполните:

```bash
# 1. Посмотрим, что внутри ar‑архива
ar t luci-app-nfqws2-1.0.0-r1.aarch64.apk
# Ожидаем три записи: debian-binary control.tar.gz data.tar.gz

# 2. Проверим каждый из них
ar p luci-app-nfqws2-1.0.0-r1.aarch64.apk data.tar.gz | file -
# Должно вывести: gzip compressed data, was "data.tar", ...

# Если вместо этого получаем "data" или пустой вывод – data.tar.gz повреждён.
```

Если `data.tar.gz` оказывается пустым или не‑gzip, проблема в **сборке пакета** – при формировании `data.tar.gz` ничего не попадает внутрь (или попадает обрезанный кусок).

---

## 3. Почему `data.tar.gz` может оказаться пустым/обрезанным

| Причина | Как проверить | Как исправить |
|---------|---------------|---------------|
| **Функция `package()` в `APKBUILD` ничего не копирует** | Посмотрите, какие файлы попадают в `$pkgdir` перед упаковкой: `find $pkgdir -type f` внутри `package()` (можно добавить временный `echo`/`ls`). | Убедитесь, что вы действительно копируете нужные каталоги (`etc/`, `usr/`, …) в `$pkgdir`. Пример:<br>`cp -a files/etc "$pkgdir/"`<br>`cp -a files/usr "$pkgdir/"` |
| **Пропущен `install -Dm…` для файлов, которые должны быть исполняемыми** | После сборки проверьте права: `tar -tzf data.tar.gz | grep -E '\.init|\.trigger'` – если файлы есть, но без `x`, apk всё равно их скопирует, но позже скрипты не исполнятся. | Добавьте `-m755` (или `-m644` для обычных файлов) при `install -D`. |
| **Используется неправильный тип сжатия** (например, вы указали `tar -cJf` → `.tar.xz`, но в `control` указано `data.tar.gz`) | Распакуйте вручную обе попытки: `tar -xzf data.tar.gz` и `tar -xJf data.tar.xz`. Одна из них сработает, другая даст ошибку. | Приведите тип сжатия в соответствии с тем, как вы упаковываете. В классическом APKBUILD используется `tar -czf` (gzip). Если хотите xz – добавьте в `ABUILD.conf` `ABUILD_COMPRESS=xz` либо явно укажите `tar -cJf`. |
| **Повреждённый кеш `src/` или `pkg/`** (например, предыдущий запуск прервался и оставил半собранный архив) | Удалите кеш и соберите заново: `rm -rf src pkg pkgdir` (или просто `abuild clean`). | Повторите сборку: `abuild -r`. |
| **Не хватает места на диске/в tmp** – архиоб записывается частично и обрывается. | Проверьте вывод `df -h` в каталоге сборки; если место закончилось, в логе будет видно “No space left on device”. | Освободите место или измените `TMPDIR` на другой диск. |
| **Ошибка в скрипте `post-install`/`pre-install`** – если скрипт завершается с ненулевым кодом до завершения распаковки, apk может прервать распаковку и выдать похожее сообщение. | Запустите установку в режиме отладки: `apk add -v luci-app-nfqws2`. Следите за выводом после “Unpacking …”. | Убедитесь, что скрипты имеют `#!/bin/sh` и не вызывают недоступных команд. Добавьте `set -e` в начало, если хотите, чтобы ошибка была явной. |

---

## 4. Как правильно собрать пакет с помощью `abuild` (пошагово)

1. **Убедитесь, что у вас есть рабочий Alpine SDK** (или любой образ, где установлен `abuild`).  
   Если работаете внутри OpenWrt SDK – можно также воспользоваться `make package/luci-app-nfqws2/compile V=s`, но принцип тот же: функция `package()` должна заполнять `$pkgdir`.

2. **Проверьте/отредактируйте `APKBUILD`** (пример минимального, но рабочего файла):

   ```bash
   # APKBUILD для luci-app-nfqws2
   pkgname=luci-app-nfqws2
   pkgver=1.0.0          # оставьте как есть, если у вас именно этот тег существует
   pkgrel=1
   pkgdesc="LuCI interface for nfqws2‑keenetic"
   arch="$CARCH"
   url="https://github.com/Brooklyn2001/luci-app-nfqws2"
   license="MIT"
   depends="nfqws2-keenetic luci-base"
   source="https://github.com/Brooklyn2001/luci-app-nfqws2/archive/v$pkgver.tar.gz"
   builddir="$srcdir/$pkgname-$pkgver"

   prepare() {
       default_prepare
       # если нужно поправить что‑то в исходниках – делаем здесь
   }

   build() {
       # ничего не компилируем – только копируем файлы
       :
   }

   package() {
       cd "$builddir"

       # --- Lua‑файлы -------------------------------------------------
       install -d "$pkgdir/usr/lib/lua/luci"
       find . -type f -name '*.lua' -exec install -Dm644 {} "$pkgdir/usr/lib/lua/luci/{}" \;

       # --- Статика (js/css/htm/html) ---------------------------------
       install -d "$pkgdir/www"
       find . -type f \( -name '*.js' -o -name '*.css' -o -name '*.htm' -o -name '*.html' \) \
           -exec install -Dm644 {} "$pkgdir/www/{}" \;

       # --- Init‑скрипт ------------------------------------------------
       install -Dm755 files/etc/init.d/nfqws2-keenetic \
           "$pkgdir/etc/init.d/nfqws2-keenetic"

       # --- UCI‑конфиг (пустой, но обязателен) ------------------------
       install -d "$pkgdir/etc/config"
       install -Dm644 files/etc/config/nfqws2 \
           "$pkgdir/etc/config/nfqws2"

       # --- Триггеры apk ------------------------------------------------
       install -d "$pkgdir/usr/share/apk/triggers"
       install -Dm755 files/usr/share/apk/triggers/nfqws2-keenetic \
           "$pkgdir/usr/share/apk/triggers/nfqws2-keenetic"
       install -Dm755 files/usr/share/apk/triggers/luci-app-nfqws2 \
           "$pkgdir/usr/share/apk/triggers/luci-app-nfqws2"
   }
   ```

   **Важные моменты**:
   * Все `install -Dm*` указывают явно права (`755` для исполняемых, `644` для обычных).
   * Директории создаются через `install -d` перед копированием.
   * После копирования **не** забывайте про `chmod +x` у триггеров и init‑скрипта (это уже сделано через `-m755`).

3. **Очистите старые артефакты и соберите заново**:

   ```bash
   # Удалим возможные бинарные остатки
   abuild clean
   # Удалим кэш загрузок (если подозреваете, что src‑архив битый)
   rm -rf src
   # Сборка
   abuild -r   # -r удалит зависимости после сборки, оставляя только .apk
   ```

   После успешного выполнения в каталоге `packages/<arch>/` появится файл, например:

   ```
   luci-app-nfqws2-1.0.0-r1.aarch64.apk
   ```

4. **Проверьте полученный .apk перед публикацией**:

   ```bash
   cd packages/aarch64
   ar t luci-app-nfqws2-1.0.0-r1.aarch64.apk
   # должно показать три файла

   # Распакуем data.tar.gz и посмотрим, что внутри
   ar p luci-app-nfqws2-1.0.0-r1.aarch64.apk data.tar.gz | tar -tzf -
   # Ожидаем увидеть etc/, usr/, … и наши файлы внутри них
   ```

   Если список не пустой и содержит ваши файлы – пакет собран корректно.

5. **Загрузите обновлённый .apk в ваш HTTP‑репозиторий**, обновите индекс:

   ```bash
   cd /path/to/your/repo/aarch64
   cp /path/to/sdk/packages/aarch64/luci-app-nfqws2-*.apk .
   apk index -o APKINDEX.tar.gz *.apk
   ```

6. **Установите на целевой роутер**:

   ```bash
   apk update
   apk add luci-app-nfqws2
   ```

   Теперь вы должны увидеть только стандартные сообщения о загрузке и распаковке, без `unexpected end of file`.

---

## 5. Если вы всё ещё используете **opkg** (а не apk)

Схема аналогична: `.ipk` – это также `ar`‑архив с `control.tar.gz` и `data.tar.gz`.  
Тот же набор проверок (`ar t`, `tar -tzf`) и те же причины (пустой `data.tar.gz`, неправильные права, неправильное сжатие) prowadят к ошибке:

```
Collected errors:
 * satisfy_dependencies_for: Cannot satisfy the following dependencies for luci-app-nfqws2:
 *  ...
 * opkg_install_cmd: Cannot install package luci-app-nfqws2.
```

Решение – пересобрать ipk корректно (через `make package/luci-app-nfqws2/compile` в SDK) и убедиться, что в `PKG_INST_DIR` попали все нужные файлы.

---

## 6. Быстрый чек‑лист перед публикацией

| Шаг | Команда | Что проверяем |
|-----|---------|---------------|
| 1 | `grep -n "package()" APKBUILD` | Есть ли функция `package()` и копирует ли она файлы в `$pkgdir`. |
| 2 | `abuild clean && rm -rf src pkg pkgdir` | Очистка возможных остатков. |
| 3 | `abuild -r` | Сборка; смотрим в конце строки `Creating APKG …`. |
| 4 | `ar pkgname-version-rx.arch.apk` | Наличие трёх частей. |
| 5 | `ar p pkgname-*.apk data.tar.gz \| tzf -` | Список файлов внутри data – не пустой и содержит нужные пути. |
| 6 | `apk add -v pkgname-version-rx.arch.apk` (на тестовом устройстве) | Установка без ошибок. |
| 7 | `apk index -o APKINDEX.tar.gz *.apk` && `apk update` | Индекс корректен. |
| 8 | `apk add pkgname` на целевой машине | Финальная проверка. |

Если любой из пунктов 4‑5 даёт пустой список или ошибку – возвращайтесь к шагу 2 и проверяйте, что в `package()` вы действительно копируете всё, что должно попасть в систему.

---

### Что делать прямо сейчас

1. **Удалите потенциально bad .apk** из вашего репозитория:

   ```bash
   rm /path/to/repo/aarch64/luci-app-nfqws2-*.apk
   ```

2. **Соберите пакет заново** по инструкции в разделе 4 (проверьте, что функция `package()` действительно копирует файлы).  
3. **Загрузите новый .apk**, обновите `APKINDEX.tar.gz`.  
4. **Попробуйте установить снова** – ошибка `unexpected end of file` должна исчезнуть.

Если после этого всё ещё появляется та же ошибка, пришлите, пожалуйста, вывод команд:

```bash
ar t <path-to>.apk
ar p <path-to>.apk data.tar.gz | file -
```

и содержащееся в вашем `APKBUILD` (особенно секцию `package()`). Тогда мы сможем точно указать, какой файл не попадает в архив.

Удачной сборки! 🚀 Если понадобится пример готового `APKBUILD` или помощь с настройкой `abuild` внутри вашего окружения – дайте знать.