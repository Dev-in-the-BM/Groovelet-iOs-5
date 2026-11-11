#!/bin/sh
# Build the Cydia package of Groovelet into build/.
# Usage: scripts/deb.sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
"$ROOT/scripts/app.sh" >/dev/null
VERSION=$(python3 -c 'import plistlib, sys; print(plistlib.load(open(sys.argv[1], "rb"))["CFBundleShortVersionString"])' "$ROOT/resources/Info.plist")
NAME="io.github.stivengjekaj.groovelet_${VERSION}_iphoneos-arm.deb"
APP="$ROOT/build/Groovelet.app"

# iOS 6 reads only the first code directory, so SHA-1 must be first.
if command -v codesign >/dev/null 2>&1; then
    for file in "$APP"/Groovelet "$APP"/*.dylib; do
        [ -f "$file" ] || continue
        codesign -s - --digest-algorithm=sha1,sha256 -f "$file" 2>/dev/null
    done
elif command -v ldid >/dev/null 2>&1; then
    for file in "$APP"/Groovelet "$APP"/*.dylib; do
        [ -f "$file" ] || continue
        ldid -S "$file"
    done
fi

STAGE="$ROOT/build/deb"
rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" "$STAGE/Applications"
cp -R "$APP" "$STAGE/Applications/"
sed "s/@VERSION@/$VERSION/" "$ROOT/packaging/control" > "$STAGE/DEBIAN/control"
cp "$ROOT/packaging/postinst" "$ROOT/packaging/postrm" "$STAGE/DEBIAN/"
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm" "$STAGE/Applications/Groovelet.app/Groovelet"
if command -v xattr >/dev/null 2>&1; then xattr -cr "$STAGE"; fi

# The dpkg of Cydia on iOS 6 reads gzip, not xz or zstd.
dpkg-deb -Zgzip --root-owner-group -b "$STAGE" "$ROOT/build/$NAME" >/dev/null
echo "$ROOT/build/$NAME"
