# Current status

**State: app opens on the iPod touch 3,1 running iOS 5.1.1.** The user confirmed that the corrected app opens after installation over USB.

**Feature implementation:** Settings selects disjoint roots under
`/var/mobile/Media`; scanning is limited to those roots, and Folders browses
and plays only their contents. Imports and Wi-Fi uploads remain in
`Media/Groovelet`. Settings also chooses up to five bottom-bar destinations
from Artists, Albums, Songs, Folders, Playlists, and Search. The default shows
all except Search; unselected destinations remain in the top-bar More page,
along with Upload and Settings. Search matches song, artist, and album text.
Folders and Search have tab icons sourced as SVG and bundled as 30px/60px PNGs.
The updated app and core-test executable compile for armv7/iOS 5.1.
The latest navigation build has been copied to `/Applications/Groovelet.app`,
signed on the iPod, and registered with `uicache`. The device has no `open`
command, so launch it by tapping its SpringBoard icon. Updated navigation and
library behavior are not yet verified on-device; tests have not been run.

- Build target: armv7, minimum iOS 5.1, using the iOS 9.3 SDK.
- App: `build/Groovelet.app/Groovelet`.
- Package: `build/io.github.stivengjekaj.groovelet_1.0.2_iphoneos-arm.deb`.
- Verification: executable is Mach-O armv7; load command sets minimum iOS 5.1; FFmpeg symbols link into the app; package depends on firmware 5.1 or later.
- Device install: app was signed on-device with `ldid` and registered with `uicache` as mobile.
- Not verified: audio playback, background audio, route changes, lock-screen controls, library scan, and upload.
- Latest pushed commit: `d4548f3` (`Add folder tab icon and update feature docs`).
  Current configurable-navigation changes are uncommitted.

See [`claude.progress.md`](claude.progress.md) for build setup, technical fixes, and test history. See [`goals.md`](goals.md) for acceptance goals.
