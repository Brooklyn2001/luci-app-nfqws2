#!/usr/bin/env python3
"""
Подпись .apk пакета для OpenWRT 25.12.

Генерирует ECDSA ключ (если нет), подписывает .apk,
выдаёт публичный ключ для импорта на роутер.

Использование:
  python sign_apk.py out/luci-app-nfqws2_1.0.0-1_all.apk
"""

import argparse
import hashlib
import hmac
import os
import struct
import sys
import tempfile
from pathlib import Path

try:
    import ecdsa
    from ecdsa import SECP256k1, SigningKey, VerifyingKey
    HAS_ECDSA = True
except ImportError:
    HAS_ECDSA = False


def gen_ecdsa_key(key_path):
    """Генерирует ECDSA secp256k1 ключ (совместим с apk)."""
    sk = SigningKey.generate(curve=SECP256k1)
    pk = sk.get_verifying_key()

    key_path.parent.mkdir(parents=True, exist_ok=True)
    key_path.write_bytes(sk.to_pem())

    pem = pk.to_pem()
    key_path.with_suffix('.pem').write_bytes(pem)

    print(f"  Ключ сгенерирован: {key_path}")
    print(f"  Публичный ключ:    {key_path.with_suffix('.pem')}")
    return sk, pk


def load_ecdsa_key(key_path):
    """Загружает существующий ECDSA ключ."""
    sk = SigningKey.from_pem(key_path.read_bytes())
    pk = sk.get_verifying_key()
    return sk, pk


def apk_signing_data(apk_path):
    """
    Извлекает данные для подписи из .apk.
    apk подписывает: размер + md5 + tar-записи .SIGN.RSA + .PKGINFO + .DIRMD5
    """
    import tarfile

    parts = {}
    sizes = {}

    with tarfile.open(apk_path, "r:gz") as tar:
        for member in tar.getmembers():
            if member.name in (".PKGINFO", ".DIRMD5") or member.name.startswith(".SIGN.RSA/"):
                f = tar.extractfile(member)
                if f:
                    data = f.read()
                    parts[member.name] = data
                    sizes[member.name] = member.size

    return parts, sizes


def compute_apk_signature(apk_path, sk):
    """
    Вычисляет подпись apk.
    Формат подписи: md5(заголовок + данные) подписанный ECDSA.
    """
    import tarfile

    # apk подписывает первые 3 блока (SIGN + PKGINFO + DIRMD5)
    # Формат: для каждого блока — md5(имя + размер + данные)
    # Затем весь буфер подписывается ECDSA

    signature_buffer = b""
    align = 65536

    with tarfile.open(apk_path, "r:gz") as tar:
        for member in tar.getmembers():
            if member.name == ".SIGN.RSA/whitespace.txt":
                continue  # саму подпись не подписываем
            if member.name in (".PKGINFO", ".DIRMD5"):
                data = tar.extractfile(member).read()
                # md5 суммы каждого блока
                buf = f"{member.name}\n{member.size}\n".encode()
                signature_buffer += buf + data

    # Подписываем
    sig = sk.sign(signature_buffer)

    # Формат подписи в apk: 4 байта типа + 4 байта длины + сигнатура + md5
    # Для APK signature version 2:
    # magic "apk.sig\005" (8 bytes)
    # + ECDSA signature (variable)
    # + md5 of the whole signature block

    magic = b"apk.sig\x05"
    sig_len = len(sig)

    # Формат: magic(8) + sig_len(4, little endian) + sig + padding
    sig_block = magic + struct.pack("<I", sig_len) + sig

    # md5 checksum всего sig_block + padding до 16
    md5 = hashlib.md5(sig_block).digest()
    # Padded to 16 bytes already (md5 is 16)
    sig_block += md5

    # Pad to 16-byte boundary
    remainder = len(sig_block) % 16
    if remainder:
        sig_block += b"\x00" * (16 - remainder)

    return sig_block


def replace_sign_in_apk(apk_path, sig_block, out_path):
    """
    Заменяет .SIGN.RSA/whitespace.txt в apk на блок с подписью.
    """
    import tarfile
    import io

    align = 65536

    # Read existing apk
    with open(apk_path, "rb") as f:
        apk_data = f.read()

    # Extract all members
    members = []
    with tarfile.open(fileobj=io.BytesIO(apk_data), mode="r:gz") as tar:
        for member in tar.getmembers():
            f = tar.extractfile(member)
            data = f.read() if f else b""
            members.append((member, data))

    # Rebuild tar.gz with signature
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(out_path, "w:gz") as tar:
        for member, data in members:
            if member.name == ".SIGN.RSA/whitespace.txt":
                # Replace with actual signature
                new_data = sig_block + b"\x00" * (align - len(sig_block) % align)
                info = tarfile.TarInfo(name=member.name)
                info.size = len(new_data)
                info.mtime = member.mtime
                info.mode = member.mode
                info.uid = member.uid
                info.gid = member.gid
                tar.addfile(info, io.BytesIO(new_data))
            else:
                info = tarfile.TarInfo(name=member.name)
                info.size = member.size
                info.mtime = member.mtime
                info.mode = member.mode
                info.uid = member.uid
                info.gid = member.gid
                tar.addfile(info, io.BytesIO(data))


def main():
    parser = argparse.ArgumentParser(description="Подпись .apk для OpenWRT 25.12")
    parser.add_argument("apk", help="Путь к .apk файлу")
    parser.add_argument("--key", default=None, help="Путь к приватному ключу (ECDSA pem)")
    parser.add_argument("--out", default=None, help="Путь для подписанного apk")
    args = parser.parse_args()

    apk_path = Path(args.apk)
    if not apk_path.exists():
        print(f"ОШИБКА: {apk_path} не найден")
        sys.exit(1)

    if not HAS_ECDSA:
        print("ОШИБКА: нужен модуль ecdsa")
        print("Установите: pip install ecdsa")
        sys.exit(1)

    key_dir = Path(".keys")
    key_path = Path(args.key) if args.key else key_dir / "signing.key"

    if not key_path.exists():
        print(f"Генерация нового ECDSA ключа...")
        sk, pk = gen_ecdsa_key(key_path)
    else:
        print(f"Загрузка ключа: {key_path}")
        sk, pk = load_ecdsa_key(key_path)

    # Compute signature
    print(f"Подписание {apk_path}...")
    sig_block = compute_apk_signature(apk_path, sk)

    # Output
    out_path = Path(args.out) if args.out else apk_path.with_name(apk_path.stem + "-signed.apk")
    replace_sign_in_apk(apk_path, sig_block, out_path)

    size = out_path.stat().st_size
    print(f"Подписанный пакет: {out_path} ({size / 1024:.1f} KB)")

    # Show install commands
    pem_path = key_path.with_suffix(".pem")
    pub_name = "luci-app-nfqws2.pem"
    print()
    print("=== Установка на роутер ===")
    print(f"scp {pem_path} root@OpenWrt:/tmp/{pub_name}")
    print(f"scp {out_path} root@OpenWrt:/tmp/")
    print("ssh root@OpenWrt 'cp /tmp/luci-app-nfqws2.pem /etc/apk/keys/ && apk add --allow-untrusted /tmp/luci-app-nfqws2-*.apk'")

    print()
    print("=== Публичный ключ ===")
    print(pem_path.read_text())


if __name__ == "__main__":
    main()
