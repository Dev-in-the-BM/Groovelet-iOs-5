# Engineering progress and handoff

This file records the technical work and reproduction details for the iOS 5.1 backport. Read [`goals.md`](goals.md) for the project objective and [`status.md`](status.md) for the current result.

## Repository and target

- Repository: Groovelet iOS 5.1 backport.
- Branch: `main`.
- Remote: `https://github.com/Dev-in-the-BM/Groovelet-iOs-5`.
- Latest committed and pushed revision: `43dba76` (`Backport Groovelet to iOS 5.1`).
- Device: iPod touch 3,1, iOS 5.1.1, armv7.
- Build SDK: iOS 9.3 SDK at `sdks/iPhoneOS9.3.sdk`. The SDK is not tracked by Git.
- Build host: Linux. The Apple linker, archiver, and ranlib tools live outside the repository at `/tmp/opencode/apple-toolchain/bin/`.

## Build and package

The project targets armv7 and iOS 5.1. The build uses Clang with the iOS 9.3 SDK and cctools-port tools. LLVM 21's Mach-O linker cannot link armv7, so use the cctools-port linker.

```sh
export IOS_LD=/tmp/opencode/apple-toolchain/bin/x86_64-apple-darwin13.4.0-ld
export IOS_AR=/tmp/opencode/apple-toolchain/bin/x86_64-apple-darwin13.4.0-ar
export IOS_RANLIB=/tmp/opencode/apple-toolchain/bin/x86_64-apple-darwin13.4.0-ranlib
./fix-sdk.sh
scripts/ffmpeg.sh
scripts/app.sh
scripts/deb.sh
```

`scripts/ffmpeg.sh` downloads FFmpeg 7.1.1 from an Ubuntu source mirror and checks SHA256 `733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1`. It builds static libraries. iOS 5 does not support app-bundled dynamic libraries. The linker and archive tools are environment dependencies and are not included in the repository.

The app output is `build/Groovelet.app`. The package output is `build/io.github.stivengjekaj.groovelet_1.0.2_iphoneos-arm.deb`. On Linux, the package script signs with `codesign` or `ldid` if available. The local Debian package has no host-side signature. The installed device copy was signed on the iPod with `ldid -S`.

The app was verified as a Mach-O armv7 executable. Its load command sets minimum iOS to 5.1 and its FFmpeg symbols are linked into the executable. The package metadata reports architecture `iphoneos-arm` and dependency `firmware (>= 5.1)`.

## Compatibility changes

- Replaced the iOS 6 album collection view with a table view.
- Added `src/core/GLCompat.m` to install missing collection subscript methods on iOS 5.
- Replaced `NSMapTable` in `GLPlayQueue` with a dictionary keyed by non-retaining object-pointer values.
- Replaced newer audio-session route handling with Audio Session Services.
- Updated source code that used APIs newer than iOS 5.
- Set the app minimum OS and Cydia firmware dependency to 5.1.
- Linked FFmpeg statically and added the missing Mach-O underscore prefix to its ARM assembly symbols.
- Updated SDK stubs so old iOS resolves `NSObject` from Foundation, not libobjc. The first attempt added a duplicate YAML `objc-classes` key and failed at link time. The final script merges `_NSObject` into the existing Foundation class list and removes it from libobjc.

## Crash investigation and device install

The first installed build crashed before the UI appeared. Three iOS crash reports showed dyld error `Symbol not found: _OBJC_CLASS_$_NSObject`, expected in `/usr/lib/libobjc.A.dylib`. The iOS 9.3 SDK stub exported `NSObject` from libobjc, but iOS 5.1.1 provides it through Foundation. The SDK stub fix changed the provider. `nm -m` on the corrected app confirms `_OBJC_CLASS_$_NSObject` is undefined from Foundation.

The iPod connected over USB. Wi-Fi SSH alias `iphone4s` did not work. A USB SSH tunnel used `iproxy 2222 22 -u <UDID>` and root SSH at `127.0.0.1:2222`. The app was copied to `/Applications/Groovelet.app`, signed on-device, set to root:admin ownership, and registered by running `uicache` as mobile. The device had no `open` command, so the user tapped the SpringBoard icon. The user confirmed the corrected app opens.

## Remaining checks

Opening the app is verified. Do not claim the other features work on iOS 5.1 until they have been tested on the device. Test playback, background audio, route changes, lock-screen controls, library scanning, and upload. No changes have been committed after `43dba76` for these handoff files unless a later commit is made.
