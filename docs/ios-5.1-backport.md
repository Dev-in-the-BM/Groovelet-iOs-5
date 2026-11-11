# iOS 5.1 backport

This branch lowers the app target to iOS 5.1 and replaces the album grid with a
table. `UICollectionView` first appears in iOS 6. The table keeps album search,
art, and album navigation.

The build uses the iOS 9.3 SDK. The compiler target is armv7 iOS 5.1. Install
that SDK in `sdks/iPhoneOS9.3.sdk` and apply `fix-sdk.sh` before you build.
The build uses Clang and the Apple linker and archive tools from cctools-port.
FFmpeg uses static libraries because iOS 5 does not support app-bundled
libraries. The app needs a jailbroken armv7 device.

The app and package build on Linux. No iOS 5.1 device or iOS 5.1 SDK is
available in this build environment. The package is not signed on hosts without
`codesign` or `ldid`. Test app launch, audio playback, background audio, route
changes, lock-screen controls, library scanning, and upload on a device before
regular use.
