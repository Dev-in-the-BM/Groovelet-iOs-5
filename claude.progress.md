# Engineering progress and handoff

This file records the technical work and reproduction details for the iOS 5.1 backport. Read [`goals.md`](goals.md) for the project objective and [`status.md`](status.md) for the current result.

## Repository and target

- Repository: Groovelet iOS 5.1 backport.
- Branch: `main`.
- Remote: `https://github.com/Dev-in-the-BM/Groovelet-iOs-5`.
- Latest pushed revision: `2710cf3` (`Add selectable music folders and browser tab`).
- Latest local commit: `fba6cbc` (`Keep folders visible in the tab bar`); the folder-icon assets are uncommitted.
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

Opening the app is verified. Do not claim the other features work on iOS 5.1 until they have been tested on the device. Test playback, background audio, route changes, lock-screen controls, library scanning, and upload. Selected folders were committed in `2710cf3`, the visible-tab adjustment in `fba6cbc`, and the folder icon/docs in `d4548f3`. Configurable tab navigation is the current uncommitted work.

## Active task: selected Media music folders

- User request: add a Settings control to choose which folders inside `/var/mobile/Media` are music roots, and a dedicated tab to browse nested folders and play music. Browsing must stay inside the selected roots.
- Preserve `Media/Groovelet` as the import and Wi-Fi-upload destination; it should remain the default selected root for existing installs.
- Implemented Settings folder selection, scoped scanning, a dedicated Folders tab, Media-relative playback paths, schema-v4 migration for old library/playlist paths, and preservation of the `Groovelet` import/upload destination.
- `scripts/app.sh` builds successfully for armv7/iOS 5.1 using the documented linker tools. The core test executable also compiles for armv7. `scripts/test.sh` cannot execute on this Linux host because its Mac test target requires the macOS Objective-C runtime and frameworks. The latest configurable-navigation app was installed over USB, signed on-device, and registered with `uicache`. The iPod's `open` command is unavailable; launch from its SpringBoard icon. Navigation behavior and runtime tests remain unverified on-device.
- A scan treats Settings' selected roots as the full library: removing a root removes its tracks from the index; selecting no roots leaves the library empty.
- Settings persists up to five visible tab identifiers from Artists, Albums, Songs, Folders, Playlists, and Search. The default is Artists, Albums, Songs, Folders, Playlists. Hidden destinations remain reachable from More.
- More is a top-right navigation-bar button, not a tab. Its pushed page lists hidden library destinations, Upload, and Settings.
- Search reuses the Songs list and matches song titles, artists, and albums, with its search field revealed immediately.
- Folders and Search use source SVGs in `assets/tabs/`, rendered to 30px/60px PNGs by `scripts/icons.sh`; iOS loads the PNG assets.
- Keep this section, `status.md`, `goals.md`, and the roadmap current as remaining verification proceeds.
