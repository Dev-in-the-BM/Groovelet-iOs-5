# Engineering progress and handoff

This is the engineering history and handoff for the iOS 5.1 backport. For
current device/build state, see [`status.md`](status.md); for reproducible
toolchain recovery and USB deployment, see
[`docs/ios-5.1-backport.md`](docs/ios-5.1-backport.md).

## Repository and target

- Repository: Groovelet iOS 5.1 backport; branch `main`.
- Remote: `https://github.com/Dev-in-the-BM/Groovelet-iOs-5`.
- Target device: iPod touch 3,1, iOS 5.1.1, armv7.
- Target minimum: iOS 5.1. Build SDK: iOS 9.3 at
  `sdks/iPhoneOS9.3.sdk` (not tracked by Git).
- Latest commit before the current working changes: `8408763` (`Add shuffle
  all to songs screen`). Follow-up work keeps More alongside Shuffle and
  refreshes the build/install documentation and scripts.

## Build and deployment (current workflow)

Do not assume an Apple linker left in `/tmp` is still available. Recreate the
armv7-capable cctools-port tools from the pinned source with:

```sh
scripts/toolchain.sh
TOOLCHAIN="$PWD/build/apple-toolchain/bin"
export IOS_LD="$TOOLCHAIN/x86_64-apple-darwin13.4.0-ld"
export IOS_AR="$TOOLCHAIN/x86_64-apple-darwin13.4.0-ar"
export IOS_RANLIB="$TOOLCHAIN/x86_64-apple-darwin13.4.0-ranlib"
scripts/app.sh
```

`scripts/toolchain.sh` pins `cctools-877.8-ld64-253.9-1`, builds into ignored
`build/`, and applies Linux compatibility patches. It was run successfully
from a clean checkout on Ubuntu 26.04 with Clang/LLVM 21 on 2026-11-11. LLVM
21's `ld64.lld` cannot link `-arch armv7`; use the pinned cctools linker.
Expected LLVM headers are `/usr/include/llvm-c-21` and
`/usr/lib/llvm-21/include` (the script's `CPPFLAGS`).

The iOS SDK must exist at `sdks/iPhoneOS9.3.sdk`; after unpacking it, run
`./fix-sdk.sh`. `scripts/app.sh` builds FFmpeg when its static libraries are
missing. FFmpeg is 7.1.1, verified by SHA256
`733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1`.
`scripts/deb.sh` builds the package. `scripts/test.sh` requires macOS frameworks
on the host; `scripts/test.sh --phone` builds/runs tests on the iPod.

The tested device uses the SSH alias `ipod` over USB: `iproxy 2222 22 -u
<UDID>` tunnels to root at `127.0.0.1:2222`. Get the UDID from
`idevice_id -l`. If port 2222 is already occupied, test `ssh ipod`; an existing
tunnel may already be serving it. Deploy with:

```sh
IOS_LD="$PWD/build/apple-toolchain/bin/x86_64-apple-darwin13.4.0-ld" \
IOS_DEVICE=ipod scripts/install.sh
```

`IOS_DEVICE` defaults to `iphone4s` for compatibility. Install copies the
bundle, signs it with device-side `ldid`, fixes ownership/mode, and runs
`uicache` as mobile. The iOS 5 device has no `open` command: launch from the
SpringBoard icon. The current build was installed and registered on 2026-11-11;
manual launch/touch verification is still pending.

## Compatibility and investigation history

- Replaced the iOS 6 album collection view with a table view (`UICollectionView`
  is not available on iOS 5).
- Added `src/core/GLCompat.m` to supply collection subscripting methods missing
  on iOS 5.
- Replaced `NSMapTable` in `GLPlayQueue` with a dictionary keyed by non-retaining
  object-pointer values; replaced newer audio-session route handling with
  Audio Session Services; adjusted other APIs for iOS 5.
- Set the minimum OS and Cydia firmware dependency to 5.1. Linked FFmpeg
  statically and fixed ARM assembly symbol prefixes.
- Corrected the iOS 9.3 SDK stubs so old iOS resolves `_NSObject` from
  Foundation rather than libobjc. The first attempt introduced duplicate YAML
  keys; the final `fix-sdk.sh` merges the symbol into Foundation and removes it
  from libobjc. A prior installed build crashed before UI due to this symbol;
  the corrected build was confirmed to open.
- Folder selection scopes scanning and playback to selected roots under
  `/var/mobile/Media`; imports/uploads stay in `Media/Groovelet`. The folder
  selector supports nested browsing, and tab settings allow up to five
  reorderable visible destinations with hidden destinations under More.

## Current feature and verification

- Songs Shuffle starts shuffled playback of the full library, regardless of
  search filtering. More and Shuffle are both assigned to the Songs root's
  right navigation items; More remains available on every root.
- App build, USB copy, on-device signing, ownership/mode setup, and `uicache`
  registration completed successfully on 2026-11-11.
- Previously, 106 core tests passed on the iPod. The new More/Shuffle layout,
  shuffle playback, audio/background/route/lock-screen flows, library scan,
  and upload still need hands-on checks. Do not claim these as verified until
  exercised on the device.
