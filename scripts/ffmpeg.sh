#!/bin/sh
# Build the audio part of FFmpeg for armv7 iOS 5.1 into build/ffmpeg/.
# The result is static libraries and headers. It holds only
# the decoders and the demuxers of the formats that iOS does not read:
# FLAC, Opus, Vorbis, APE, and WavPack. It also holds the resampler.
# FFmpeg is LGPL. The build has no --enable-gpl and no --enable-nonfree.
# Usage: scripts/ffmpeg.sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SDK="$ROOT/sdks/iPhoneOS9.3.sdk"
VERSION=7.1.1
SHA256=733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1
DL="$ROOT/build/dl"
SRC="$ROOT/build/ffmpeg-src/ffmpeg-$VERSION"
OUT="$ROOT/build/ffmpeg"

mkdir -p "$DL"
TARBALL="$DL/ffmpeg-$VERSION.tar.xz"
if [ ! -f "$TARBALL" ]; then
    # The archive mirror has the upstream source file and the same SHA256.
    curl --retry 3 --retry-all-errors --retry-delay 2 -sSfL \
        "http://archive.ubuntu.com/ubuntu/pool/universe/f/ffmpeg/ffmpeg_$VERSION.orig.tar.xz" \
        -o "$TARBALL"
fi
echo "$SHA256  $TARBALL" | shasum -a 256 -c - >/dev/null

if [ ! -d "$SRC" ]; then
    mkdir -p "$ROOT/build/ffmpeg-src"
    tar -C "$ROOT/build/ffmpeg-src" -xf "$TARBALL"
fi

# The movrelx macro puts a pointer in the non-lazy pointer section with the
# label ".Lpic". On Darwin, only an "L" label is local. The new Apple linker
# stops with an assertion when a pointer in that section has a name.
sed -i.bak 's/ldpic           \\rd, \.Lpic\\@, indir=1/ldpic           \\rd, Lnlp\\@, indir=1/;' \
    "$SRC/libavutil/arm/asm.S"
rm -f "$SRC/libavutil/arm/asm.S.bak"
perl -0pi -e 's/(\.non_lazy_symbol_pointer\n)\.Lpic\\@:/$1Lnlp\\@:/' "$SRC/libavutil/arm/asm.S"

TARGET="-target armv7-apple-ios5.1 -isysroot $SDK -Wno-incompatible-sysroot"
CLANG=${IOS_CLANG:-clang}
AR=${IOS_AR:-ar}
RANLIB=${IOS_RANLIB:-ranlib}
LINKER_FLAG=""
if [ -n "${IOS_LD:-}" ]; then LINKER_FLAG="-fuse-ld=$IOS_LD"; fi
STAGE="$ROOT/build/ffmpeg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cd "$STAGE"

"$SRC/configure" \
    --prefix="$STAGE/install" \
    --enable-cross-compile --target-os=darwin --arch=arm --cpu=cortex-a9 \
    --cc="$CLANG" --as="$CLANG" --ar="$AR" --ranlib="$RANLIB" \
    --extra-cflags="$TARGET -marm -mfpu=neon" \
    --extra-ldflags="$TARGET $LINKER_FLAG" \
    --enable-static --disable-shared --enable-pic \
    --disable-programs --disable-doc --disable-debug \
    --disable-everything \
    --disable-avdevice --disable-avfilter --disable-postproc --disable-swscale \
    --enable-avcodec --enable-avformat --enable-swresample \
    --enable-protocol=file \
    --enable-demuxer=flac,ogg,ape,wv,matroska \
    --enable-decoder=flac,opus,vorbis,ape,wavpack \
    --enable-parser=flac,opus,vorbis \
    --disable-videotoolbox --disable-audiotoolbox --disable-securetransport \
    --disable-sdl2 --disable-xlib --disable-bzlib --disable-lzma --disable-zlib \
    --disable-iconv --disable-hwaccels --disable-devices --disable-filters \
    --disable-network >"$STAGE/configure.log" 2>&1 ||
    { tail -30 "$STAGE/configure.log"; exit 1; }

# The 9.3 SDK has functions that iOS 6 does not have. configure finds them
# and FFmpeg then calls them. Turn them off.
for name in CLOCK_GETTIME; do
    sed -i.bak "s/^#define HAVE_$name 1/#define HAVE_$name 0/" config.h
    rm -f config.h.bak
done

# Mach-O assembly symbols need the underscore that the C compiler adds.
sed -i.bak 's/^#define EXTERN_PREFIX ""/#define EXTERN_PREFIX "_"/; s/^#define EXTERN_ASM *$/#define EXTERN_ASM _/' config.h
rm -f config.h.bak

JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
make -j"$JOBS" >"$STAGE/make.log" 2>&1 || { grep -m 20 -B2 -A5 'error' "$STAGE/make.log"; exit 1; }
make install >/dev/null

# Keep the libraries static. iOS 5 does not support app-bundled dylibs.
rm -rf "$OUT"
mkdir -p "$OUT/lib"
cp -R "$STAGE/install/include" "$OUT/include"
cp "$STAGE/install/lib/libavformat.a" "$STAGE/install/lib/libavcodec.a" \
    "$STAGE/install/lib/libswresample.a" "$STAGE/install/lib/libavutil.a" "$OUT/lib/"
echo "$OUT/lib/libavformat.a"
