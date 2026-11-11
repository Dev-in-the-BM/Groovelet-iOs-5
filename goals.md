# Project goals

Backport Groovelet to iOS 5.1 for jailbroken armv7 devices. Build a working app and Cydia package with static FFmpeg libraries. Keep the existing music library, playback, and upload features where the older OS allows them.

Success means that the app builds, installs, and opens on an iOS 5.1 device. Test playback and other device features separately before calling them verified.

## Implemented feature: selected Media folders

Let the owner select one or more folders under `/var/mobile/Media` in Settings.
Index audio and playlist files only inside those selected folders, and provide
a dedicated Folders tab that browses their nested directories and plays their
tracks. In Settings, let the owner choose up to five of Artists, Albums, Songs,
Folders, Playlists, and Search for the tab bar. Keep unselected destinations,
Upload, and Settings reachable from a top-bar More page. Preserve the existing
`Media/Groovelet` import/upload destination.
Acceptance: selecting or deselecting roots updates the library safely; browsing
never exposes directories outside selected roots; playback resolves files from
all selected roots; tab-bar selection persists and stays within iOS's five-item
limit; tab destinations can be reordered; selecting a destination in Settings
only toggles its checkmark and does not navigate away; unselected destinations
remain available from More; the Folders and Search tabs have generated PNG
icons; iOS 5.1 compatibility and existing library data are kept.

Implementation is present and installed on the iPod touch 3,1. Hands-on checks
of the folder/tab interactions remain pending; see [status.md](status.md).

## Recent feature: Shuffle beside More

Songs exposes a Shuffle action beside More in the top navigation bar. It starts
shuffled playback of the full library, independent of search filtering. The
layout and install are complete; visually verify both buttons and test playback
on the device before marking this behavior verified.
