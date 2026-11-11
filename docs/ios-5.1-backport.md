# iOS 5.1 backport: build, install, and recovery

This branch targets armv7 and iOS 5.1, using the iOS 9.3 SDK. The SDK is not
tracked by Git. This document and `scripts/toolchain.sh` are the durable build
instructions; do not rely on binaries under `/tmp`, which may disappear between
sessions.

## One-time prerequisites

- Linux x86_64 with Clang, LLVM 21 development files, GNU make, autoconf,
  automake, libtool, Git, Python 3, and the usual C/C++ build tools.
- The iOS 9.3 SDK at `sdks/iPhoneOS9.3.sdk`. Download the SDK archive from
  [theos/sdks](https://github.com/theos/sdks/releases) and unpack it there.
- A jailbroken armv7 iPhone/iPod running iOS 5.1 or later for installation.

Apply the SDK compatibility edits once after unpacking or restoring the SDK:

```sh
./fix-sdk.sh
```

## Build on Linux

LLVM 21's bundled `ld64.lld` rejects `-arch armv7`; do not point `IOS_LD` at
`ld64.lld`. Rebuild the pinned, armv7-capable cctools-port linker instead:

```sh
scripts/toolchain.sh
```

The script pins upstream tag `cctools-877.8-ld64-253.9-1`, builds into the
ignored `build/` directory, and applies the small Linux compatibility fixes
needed by this old linker source. It produces the linker, archiver, and ranlib
there. It was verified on the current Ubuntu 26.04/Clang 21 host. If LLVM's
installed header locations differ, adjust `CPPFLAGS` in the script; the tested
paths are `/usr/include/llvm-c-21` and `/usr/lib/llvm-21/include`.

Build the app (FFmpeg is built automatically if its static libraries are
missing):

```sh
TOOLCHAIN="$PWD/build/apple-toolchain/bin"
export IOS_LD="$TOOLCHAIN/x86_64-apple-darwin13.4.0-ld"
export IOS_AR="$TOOLCHAIN/x86_64-apple-darwin13.4.0-ar"
export IOS_RANLIB="$TOOLCHAIN/x86_64-apple-darwin13.4.0-ranlib"
scripts/app.sh
```

Other build commands: `scripts/deb.sh` creates the Cydia package;
`scripts/ffmpeg.sh` rebuilds the static audio decoders; `scripts/test.sh` runs
the core tests on macOS, and `scripts/test.sh --phone` builds/runs tests on the
device. The ordinary `scripts/test.sh` is not runnable on Linux because it
links macOS Foundation/CoreGraphics/ImageIO frameworks.

## Install over USB

The tested SSH setup uses the SSH alias `ipod` (`root@127.0.0.1`, port 2222)
and a USB tunnel. Confirm the device is connected and get its UDID:

```sh
idevice_id -l
```

Start the tunnel using that UDID and leave it running. If port 2222 is already
in use, a tunnel may already be running; test `ssh ipod` before starting a
second one.

```sh
iproxy 2222 22 -u DEVICE_UDID
ssh ipod 'uname -a'
```

Install using the existing tunnel and toolchain. `IOS_DEVICE` selects the SSH
alias; its default remains `iphone4s` for existing setups. The install script
builds, copies, signs with on-device `ldid`, fixes ownership/mode, and runs
`uicache` as mobile:

```sh
IOS_LD="$PWD/build/apple-toolchain/bin/x86_64-apple-darwin13.4.0-ld" \
IOS_DEVICE=ipod scripts/install.sh
```

The old iOS device has no `open` command. After installation, launch Groovelet
by tapping its SpringBoard icon. The script deliberately reports this instead
of failing while trying to launch it.

## Current device state

As of 2026-11-11, the app was built and installed on an iPod touch 3,1
(iOS 5.1.1, armv7) over USB. The installed bundle was signed with `ldid` and
registered with `uicache`. Songs now has **Shuffle** beside **More** in the
navigation bar. Source/build/install were verified; manually launching the
icon and checking the two-button layout and shuffle playback still require a
touch check on the device.

The package and app outputs are under `build/`, which is ignored and can be
regenerated. For prior compatibility fixes and investigation history, see
[`claude.progress.md`](../claude.progress.md); for current verification state,
see [`status.md`](../status.md).
