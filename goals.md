# Project goals

Backport Groovelet to iOS 5.1 for jailbroken armv7 devices. Build a working app and Cydia package with static FFmpeg libraries. Keep the existing music library, playback, and upload features where the older OS allows them.

Success means that the app builds, installs, and opens on an iOS 5.1 device. Test playback and other device features separately before calling them verified.

## Current feature goal: selected Media folders

Let the owner select one or more folders under `/var/mobile/Media` in Settings.
Index audio and playlist files only inside those selected folders, and provide
a dedicated Folders tab that browses their nested directories and plays their
tracks. Keep Folders visible with Artists, Albums, and Songs; put Playlists,
Upload, and Settings in More to fit iOS's four direct tabs plus More. Preserve
the existing `Media/Groovelet` import/upload destination.
Acceptance: selecting or deselecting roots updates the library safely; browsing
never exposes directories outside selected roots; playback resolves files from
all selected roots; the Folders tab has a generated PNG icon; iOS 5.1
compatibility and existing library data are kept.
