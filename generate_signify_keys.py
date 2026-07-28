#!/usr/bin/env python3
"""Generate signify-compatible Ed25519 key pair."""
import base64
import sys
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization


def main():
    private_key = Ed25519PrivateKey.generate()

    # Extract 32-byte seed from PKCS8 DER
    der = private_key.private_bytes(
        serialization.Encoding.DER,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption()
    )
    seed = der[-32:]

    # Get 32-byte public key
    pub_bytes = private_key.public_key().public_bytes(
        serialization.Encoding.Raw,
        serialization.PublicFormat.Raw
    )

    seed_b64 = base64.b64encode(seed).decode()
    pub_b64 = base64.b64encode(pub_bytes).decode()

    pub_path = sys.argv[1] if len(sys.argv) > 1 else "public-key.pem"
    priv_path = sys.argv[2] if len(sys.argv) > 2 else "private-key.pem"

    pub_content = f"signify:openbsd:{pub_b64}\n"
    with open(pub_path, "w", newline="\n") as f:
        f.write(pub_content)
    print(f"Public key  -> {pub_path}")
    print(f"  {pub_content.strip()}")

    priv_content = (
        f"signify:openbsd:{pub_b64}\n"
        f"# ----- BEGIN SIGNIFYING PRIVATE KEY -----\n"
        f"# Comment: (none)\n"
        f"{seed_b64}\n"
        f"# ------ END SIGNIFYING PRIVATE KEY ------\n"
    )
    with open(priv_path, "w", newline="\n") as f:
        f.write(priv_content)
    print(f"\nPrivate key -> {priv_path}")
    print(f"  {priv_content.strip()}")

    print(f"\n=== Add to GitHub Secrets ===")
    print(f"  OPENWRT_APK_PUBLIC_KEY <- {pub_path}")
    print(f"  OPENWRT_APK_SECRET_KEY <- {priv_path}")


if __name__ == "__main__":
    main()
