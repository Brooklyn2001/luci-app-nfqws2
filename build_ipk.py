#!/usr/bin/env python3
"""Сборка .ipk и .apk пакета luci-app-nfqws2 без OpenWRT SDK."""

import argparse
import io
import os
import struct
import tarfile
import time
from pathlib import Path


def build_control_text(version, release, arch):
    """Генерирует control-файл."""
    return (
        f"Package: luci-app-nfqws2\n"
        f"Version: {version}-{release}\n"
        f"Section: luci\n"
        f"Architecture: {arch}\n"
        f"Maintainer: nfqws2 <nfqws2@example.com>\n"
        f"Source: luci.apps.nfqws2\n"
        f"SourceName: luci-app-nfqws2\n"
        f"Depends: libc, luci-base, curl\n"
        f"Conffiles:\n"
        f"/etc/config/nfqws2\n"
        f"Description: NFQWS2 DPI Bypass Web Interface\n"
        f" Web interface for managing nfqws2 DPI bypass utility.\n"
    )


def copy_tree_recursive(src, dst, strip=0):
    """Рекурсивное копирование файлов из src в dst."""
    import shutil
    if not src.exists():
        return
    for item in src.rglob("*"):
        if not item.is_file():
            continue
        rel = item.relative_to(src)
        parts = rel.parts
        if strip:
            parts = parts[strip:]
        if not parts:
            continue
        target = dst.joinpath(*parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(item, target)


def build_data(root_dir, pkg_dir):
    """Собирает данные пакета в root_dir."""
    # root/ → корень
    copy_tree_recursive(pkg_dir / "root", root_dir, strip=0)

    # luasrc/ → /usr/lib/lua/luci/
    lua_dst = root_dir / "usr" / "lib" / "lua" / "luci"
    lua_dst.mkdir(parents=True, exist_ok=True)
    copy_tree_recursive(pkg_dir / "luasrc", lua_dst, strip=0)

    # htdocs/ → /www/
    if (pkg_dir / "htdocs").exists():
        www_dst = root_dir / "www"
        www_dst.mkdir(parents=True, exist_ok=True)
        copy_tree_recursive(pkg_dir / "htdocs", www_dst, strip=0)

    # po/ → /usr/lib/lua/luci/i18n/<lang>/
    po_dir = pkg_dir / "po"
    if po_dir.exists():
        for lang_dir in po_dir.iterdir():
            if not lang_dir.is_dir() or lang_dir.name == "templates":
                continue
            i18n = root_dir / "usr" / "lib" / "lua" / "luci" / "i18n" / lang_dir.name
            i18n.mkdir(parents=True, exist_ok=True)
            for po_file in lang_dir.glob("*.po"):
                base = po_file.stem
                (i18n / f"{base}.lmo").write_bytes(po_file.read_bytes())


def build_ipk(pkg_dir, out_path):
    """Собирает .ipk (ar-архив) из структуры пакета."""
    pkg_dir = Path(pkg_dir)
    version, release, arch = "1.0.0", "1", "all"

    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        root_dir = tmp / "root"
        root_dir.mkdir()
        build_data(root_dir, pkg_dir)

        # data.tar.gz
        data_tar = tmp / "data.tar.gz"
        with tarfile.open(data_tar, "w:gz") as tar:
            for dirpath, dirnames, filenames in os.walk(root_dir):
                for fname in filenames:
                    fpath = Path(dirpath) / fname
                    arcname = str(fpath.relative_to(root_dir)).replace("\\", "/")
                    tar.add(fpath, arcname=arcname)

        # control.tar.gz
        control_tar = tmp / "control.tar.gz"
        control_text = build_control_text(version, release, arch)
        with tarfile.open(control_tar, "w:gz") as tar:
            data = control_text.encode("utf-8")
            info = tarfile.TarInfo(name="control")
            info.size = len(data)
            info.mtime = int(time.time())
            tar.addfile(info, io.BytesIO(data))

        # signature.tar.gz
        sig_tar = tmp / "signature.tar.gz"
        with tarfile.open(sig_tar, "w:gz") as tar:
            info = tarfile.TarInfo(name=".packageinfo")
            info.size = 0
            info.mtime = int(time.time())
            tar.addfile(info)

        # ar-архив
        ar_magic = b"!<arch>\n"
        entries = [
            ("control.tar.gz", control_tar),
            ("data.tar.gz", data_tar),
            ("signature.tar.gz", sig_tar),
        ]

        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "wb") as arf:
            arf.write(ar_magic)
            for name, path in entries:
                data = path.read_bytes()
                size = len(data)
                mtime = str(int(time.time())).ljust(12)
                header_str = f"{name:<16}{mtime}0     0     100644  {size:010d} \n"
                arf.write(header_str.encode("ascii"))
                arf.write(data)
                if size % 2 != 0:
                    arf.write(b"\n")

    return out_path


def build_apk(pkg_dir, out_path):
    """Собирает .apk v2 (tar.gz) для OpenWRT 24.10+ / Keenetic OS.

    Формат apk v2:
      1. .SIGN.RSA/whitespace.txt — 64KB блок (пустой/подпись)
      2. .PKGINFO — 64KB блок с метаданными
      3. .DIRMD5 — 64KB блок с md5 директорий
      4. Файлы пакета с префиксом ./
    """
    import hashlib
    import tempfile

    pkg_dir = Path(pkg_dir)
    version, release, arch = "1.0.0", "1", "all"
    ALIGN = 65536  # 64 KiB

    tmp = Path(tempfile.mkdtemp())
    root_dir = tmp / "root"
    root_dir.mkdir()
    build_data(root_dir, pkg_dir)

    out_path.parent.mkdir(parents=True, exist_ok=True)

    # Собираем список файлов и директорий
    file_list = []
    dir_set = set()
    for dirpath, dirnames, filenames in os.walk(root_dir):
        rel_dir = str(Path(dirpath).relative_to(root_dir)).replace("\\", "/")
        if rel_dir != ".":
            dir_set.add(rel_dir)
        for fname in filenames:
            fpath = Path(dirpath) / fname
            arcname = "./" + str(fpath.relative_to(root_dir)).replace("\\", "/")
            file_list.append((fpath, arcname))

    # .DIRMD5 — md5 каждой директории (конкатенация md5 файлов в ней)
    dir_md5_lines = []
    for d in sorted(dir_set):
        md5 = hashlib.md5()
        for fpath, arcname in file_list:
            file_dir = str(Path(arcname.lstrip("./")).parent)
            if file_dir == d:
                md5.update(fpath.read_bytes())
        dir_md5_lines.append(f"{md5.hexdigest()}  ./{d}")
    dir_md5_text = "\n".join(dir_md5_lines) + "\n" if dir_md5_lines else ""

    # Функция: записать tar-запись с padding до ALIGN
    def add_aligned_tar(tar, name, data, size=None):
        if size is None:
            size = len(data)
        info = tarfile.TarInfo(name=name)
        info.size = size + (ALIGN - size % ALIGN) if size % ALIGN else size
        info.mtime = int(time.time())
        padded = data + b"\x00" * (info.size - len(data))
        tar.addfile(info, io.BytesIO(padded))

    # .PKGINFO — формат apk (key = value)
    pkginfo_lines = [
        f"pkgname = luci-app-nfqws2",
        f"pkgver = {version}-{release}",
        f"arch = {arch}",
        f"license = GPL-2.0",
        f"depend = libc",
        f"depend = luci-base",
        f"tag = luci-app-nfqws2",
        f"desc = NFQWS2 DPI Bypass Web Interface",
        f"url = https://github.com/bfmlb/nfqws2-openwrt",
    ]
    pkginfo_text = "\n".join(pkginfo_lines) + "\n"

    with tarfile.open(out_path, "w:gz") as tar:
        # 1. .SIGN.RSA/whitespace.txt — пустой 64KB блок
        sign_data = b" "
        add_aligned_tar(tar, ".SIGN.RSA/whitespace.txt", sign_data)

        # 2. .PKGINFO — 64KB блок
        add_aligned_tar(tar, ".PKGINFO", pkginfo_text.encode("utf-8"))

        # 3. .DIRMD5 — 64KB блок
        add_aligned_tar(tar, ".DIRMD5", dir_md5_text.encode("utf-8") if dir_md5_text else b"")

        # 4. Файлы пакета
        for fpath, arcname in file_list:
            tar.add(fpath, arcname=arcname)

    # Cleanup
    import shutil
    shutil.rmtree(tmp)

    return out_path

    return out_path


def main():
    parser = argparse.ArgumentParser(description="Сборка luci-app-nfqws2")
    parser.add_argument("--pkg-dir", default="luci-app-nfqws2", help="Директория пакета")
    parser.add_argument("--out-dir", default="out", help="Директория вывода")
    parser.add_argument("--format", choices=["ipk", "apk", "both"], default="both",
                        help="Формат: ipk (opkg), apk (Keenetic OS/OpenWRT 24.10+), both")
    args = parser.parse_args()

    pkg_dir = Path(args.pkg_dir)
    if not pkg_dir.exists():
        print(f"ОШИБКА: {pkg_dir} не найдена")
        exit(1)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(exist_ok=True)

    fmt = args.format if args.format != "both" else ["ipk", "apk"]
    if isinstance(fmt, str):
        fmt = [fmt]

    results = []
    for f in fmt:
        if f == "ipk":
            out_path = out_dir / "luci-app-nfqws2_1.0.0-1_all.ipk"
            print(f"=== Сборка .ipk ===")
            build_ipk(pkg_dir, out_path)
            results.append(out_path)
        elif f == "apk":
            out_path = out_dir / "luci-app-nfqws2_1.0.0-1_all.apk"
            print(f"=== Сборка .apk ===")
            build_apk(pkg_dir, out_path)
            results.append(out_path)

    print()
    print("=== Готово ===")
    for p in results:
        size = p.stat().st_size
        print(f"  {p.name} ({size / 1024:.1f} KB)")


if __name__ == "__main__":
    main()
