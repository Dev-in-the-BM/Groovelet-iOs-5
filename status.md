# Current status

**State: app opens on the iPod touch 3,1 running iOS 5.1.1.** The user confirmed that the corrected app opens after installation over USB.

**Feature implementation:** Settings now selects disjoint roots under
`/var/mobile/Media`; scanning is limited to those roots, and the Folders tab
browses/plays only their contents. Imports and Wi-Fi uploads remain in
`Media/Groovelet`. The app and core-test executable compile for armv7/iOS 5.1.
The visible tabs are Artists, Albums, Songs, Folders, and More; More contains
Playlists, Upload, and Settings.
Folders has a matching tab-bar glyph. Its SVG source is rendered to 30px and
60px PNG assets, and the updated app has been installed on the iPod.
The updated app has been copied to `/Applications/Groovelet.app`, signed on the
iPod, and registered with `uicache`. The device has no `open` command, so launch
it by tapping its SpringBoard icon. Updated UI/library behavior is not yet
verified on-device, and tests have not been executed.

- Build target: armv7, minimum iOS 5.1, using the iOS 9.3 SDK.
- App: `build/Groovelet.app/Groovelet`.
- Package: `build/io.github.stivengjekaj.groovelet_1.0.2_iphoneos-arm.deb`.
- Verification: executable is Mach-O armv7; load command sets minimum iOS 5.1; FFmpeg symbols link into the app; package depends on firmware 5.1 or later.
- Device install: app was signed on-device with `ldid` and registered with `uicache` as mobile.
- Not verified: audio playback, background audio, route changes, lock-screen controls, library scan, and upload.
- Latest local commit: `fba6cbc` (`Keep folders visible in the tab bar`). The
  folder-icon and documentation updates are currently uncommitted.

See [`claude.progress.md`](claude.progress.md) for build setup, technical fixes, and test history. See [`goals.md`](goals.md) for acceptance goals.
