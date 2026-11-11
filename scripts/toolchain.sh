#!/bin/sh
# Build the pinned cctools-port linker, ar, and ranlib for the iOS armv7 build.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
SRC="$BUILD/cctools-port-877.8"
PREFIX="$BUILD/apple-toolchain"
TARGET=x86_64-apple-darwin13.4.0
JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)
CPPFLAGS="-I/usr/include/llvm-c-21 -I/usr/lib/llvm-21/include"

if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$BUILD"
    git clone --depth 1 --branch cctools-877.8-ld64-253.9-1 \
        https://github.com/tpoechtrager/cctools-port.git "$SRC"
fi

# Portability fixes for the pinned 2018 sources on current Linux hosts.
python3 - "$SRC/cctools" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])

def replace(path, old, new):
    p = root / path
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Expected source context not found: {path}")
    p.write_text(text.replace(old, new, 1))

replace("libstuff/macosx_deployment_target.c",
        "#include <sys/sysctl.h>",
        "#ifdef __APPLE__\n#include <sys/sysctl.h>\n#endif")
replace("include/foreign/sys/sysctl.h",
        "#ifndef __CYGWIN__\n#include_next <sys/sysctl.h>\n#else",
        "#if defined(__APPLE__)\n#include_next <sys/sysctl.h>\n#elif defined(__CYGWIN__)")
replace("ld64/src/ld/code-sign-blobs/blob.h",
        "\tvoid length(size_t size)\t\t\t{ mLength = size; }",
        "\tvoid length(size_t size)\t\t\t{ mLength = size; }\n"
        "\tBlobCore *clone() const\n"
        "\t{ BlobCore *copy = (BlobCore *)malloc(length()); memcpy(copy, this, length()); return copy; }")
PY

cd "$SRC/cctools"
./autogen.sh
CPPFLAGS="$CPPFLAGS" ./configure --prefix="$PREFIX" --target="$TARGET" \
    --with-llvm-config=/usr/bin/llvm-config-21
make -j"$JOBS" -C libstuff CPPFLAGS="$CPPFLAGS"
make -j"$JOBS" -C ar CPPFLAGS="$CPPFLAGS"
make -j"$JOBS" -C misc CPPFLAGS="$CPPFLAGS" ranlib
make -j"$JOBS" -C ld64 CPPFLAGS="$CPPFLAGS"
make -C ar install CPPFLAGS="$CPPFLAGS"
make -C ld64 install CPPFLAGS="$CPPFLAGS"
install -m 755 misc/ranlib "$PREFIX/bin/$TARGET-ranlib"

printf 'Toolchain ready in %s\n' "$PREFIX/bin"
