# Current status

**State: app opens on the iPod touch 3,1 running iOS 5.1.1.** The user confirmed that the corrected app opens after installation over USB.

- Build target: armv7, minimum iOS 5.1, using the iOS 9.3 SDK.
- App: `build/Groovelet.app/Groovelet`.
- Package: `build/io.github.stivengjekaj.groovelet_1.0.2_iphoneos-arm.deb`.
- Verification: executable is Mach-O armv7; load command sets minimum iOS 5.1; FFmpeg symbols link into the app; package depends on firmware 5.1 or later.
- Device install: app was signed on-device with `ldid` and registered with `uicache` as mobile.
- Not verified: audio playback, background audio, route changes, lock-screen controls, library scan, and upload.
- Last commit: `43dba76` (`Backport Groovelet to iOS 5.1`), pushed to `origin/main`.

See [`claude.progress.md`](claude.progress.md) for build setup, technical fixes, and test history. See [`goals.md`](goals.md) for acceptance goals.
