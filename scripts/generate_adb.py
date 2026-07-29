import tarfile
import hashlib
import io
import gzip
import sys

apk_path = sys.argv[1] if len(sys.argv) > 1 else "luci-app-nfqws2.apk"
adb_path = sys.argv[2] if len(sys.argv) > 2 else "packages.adb"

with open(apk_path, "rb") as f:
    data = f.read()
size = len(data)
sha256 = hashlib.sha256(data).hexdigest()

# APK v3 (ADBd) format — read raw bytes to parse
# Check if it's zstd compressed (magic: 28 05)
with open(apk_path, "rb") as f:
    magic = f.read(4)
print("  APK magic: %s" % magic.hex())

# Try to find control data by scanning for known APK v3 structure
# APK v3 structure: [manifest + control + data + signature]
# Read the whole file and search for control.tar.gz or control/
with open(apk_path, "rb") as f:
    data = f.read()

# Look for "control" string occurrences
import re
for m in re.finditer(b'control', data):
    start = max(0, m.start() - 20)
    end = min(len(data), m.end() + 40)
    print("  Found 'control' at offset %d: %s" % (m.start(), data[start:end].hex()))

ctl_tar = tarfile.open(fileobj=io.BytesIO(control_data))
control_file = ctl_tar.extractfile("control")
control_text = control_file.read().decode()
ctl_tar.close()

pkg_name = "luci-app-nfqws2"
pkg_version = "1.0.0-r1"
pkg_arch = "noarch"
for line in control_text.splitlines():
    if line.startswith("PACKAGE="):
        pkg_name = line.split("=", 1)[1]
    elif line.startswith("VERSION="):
        pkg_version = line.split("=", 1)[1]
    elif line.startswith("ARCHITECTURE="):
        pkg_arch = line.split("=", 1)[1]

adb_control = "package: %s\nversion: %s\narch: %s\nsize: %d\nsha256: %s\ndescription: LuCI web interface for nfqws2 DPI bypass utility\n" % (
    pkg_name, pkg_version, pkg_arch, size, sha256
)

tar_buf = io.BytesIO()
with tarfile.open(fileobj=tar_buf, mode="w") as tar:
    info = tarfile.TarInfo(name="control")
    info.size = len(adb_control.encode())
    tar.addfile(info, io.BytesIO(adb_control.encode()))
tar_buf.seek(0)

with gzip.open(adb_path, "wb") as gz:
    gz.write(tar_buf.read())

print("packages.adb created for %s %s (%s)" % (pkg_name, pkg_version, pkg_arch))
