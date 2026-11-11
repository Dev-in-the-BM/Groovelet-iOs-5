# Current status

**Device:** Groovelet is installed on the iPod touch 3,1 (iOS 5.1.1, armv7).
The latest app was rebuilt, copied over USB, signed with on-device `ldid`, and
registered with `uicache` on 2026-11-11. Launch it by tapping the SpringBoard
icon; this iOS version has no `open` command. The latest installation has not
yet been manually launched or touch-tested.

**Latest feature:** Songs has a Shuffle button next to More in the top
navigation bar. It shuffles the full library, not only the current search
results. The app build and USB install completed; verify the side-by-side
layout and playback by touch on-device.

**Implemented library behavior:** Settings chooses music roots under
`/var/mobile/Media`; scans and Folders are scoped to those roots. Imports and
Wi-Fi uploads remain in `Media/Groovelet`. Settings can show up to five
reorderable destinations among Artists, Albums, Songs, Folders, Playlists, and
Search. Hidden destinations remain under More.

- App executable: `build/Groovelet.app/Groovelet` (Mach-O armv7, minimum iOS
  5.1).
- SDK: `sdks/iPhoneOS9.3.sdk` (not tracked by Git; run `fix-sdk.sh` after
  restoring it).
- Rebuild toolchain: `scripts/toolchain.sh`, pinned cctools-port, outputs in
  `build/apple-toolchain/bin/`.
- Build/install details and the known recovery steps:
  [`docs/ios-5.1-backport.md`](docs/ios-5.1-backport.md).
- Core tests previously passed on the iPod (106 tests). The new navigation
  controls, shuffle playback, and the remaining audio/library/upload flows
  still need hands-on verification.

See [`claude.progress.md`](claude.progress.md) for historical compatibility
work and [`goals.md`](goals.md) for acceptance goals.
