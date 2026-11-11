# Architecture

Groovelet is one iOS app in Objective-C with ARC. It uses the frameworks of
iOS 6, SQLite, and an audio-only build of FFmpeg.

## The path of a track

```
file -> decoder -> gain -> renderer -> AudioQueue -> speaker, headphones, or AirPlay
```

1. **Decoder.** `GLOpenDecoder` picks the decoder by the extension.
   `GLAppleDecoder` reads MP3, AAC, ALAC, WAV, and AIFF with ExtAudioFile.
   `GLFFmpegDecoder` reads FLAC, Opus, Vorbis, APE, and WavPack. Each decoder
   gives 44100 Hz stereo 16-bit samples, so the resampler of the decoder
   changes the rate and the channels.
2. **Gain.** `GLGainDecoder` multiplies the samples by the ReplayGain factor
   of the track. A track with no gain skips this step.
3. **Renderer.** `GLRenderer` fills the buffers of the output. When the
   current track ends inside a buffer, the next track starts in the same
   buffer. The renderer counts the frames, and keeps the frame where each
   track starts.
4. **Output.** `GLAudioPlayer` runs one AudioQueue with 4 buffers of 8192
   frames. Its clock tells which frame plays now, and the renderer tells
   which track and which time that is.
5. **Playback.** `GLPlayback` joins the play queue and the player. It gives
   the player the next track when a track starts, obeys the remote controls,
   shows the track on the lock screen, counts the plays, and saves the queue.

## The library

```
selected folders under Media -> scan -> tag reader -> SQLite index -> lists
```

1. **Scan.** `GLScanner` walks only the folders selected in Settings under
   `/var/mobile/Media`. Track paths are relative to `Media`; the default root
   is `Groovelet`. It compares file size and modification time, and reads only
   new and changed files. Import and Wi-Fi upload still write to
   `Media/Groovelet`.
   Schema migration 4 moves existing indexed paths under the `Groovelet/`
   prefix so old tracks, playlists, and saved queues continue to resolve.
   A scan treats the chosen roots as the whole library: deselected roots are
   removed from the index, and an empty selection indexes no music.
2. **Tags.** `GLTags` reads ID3v2, ID3v1, MP4, Vorbis comments, APEv2, and the
   chunks of WAV and AIFF. It skips the bytes of a picture during a scan.
3. **Index.** `GLLibrary` keeps one row for each file, the playlists, and the
   play counts. Covering indexes give the long lists in order with no sort.
4. **Art.** `GLArtCache` makes square JPEG copies of the art at the size of
    each view, and keeps them on disk. `GLImageLoader` loads them away from the
    main thread.

## Navigation

`GLSettings.tabBarOrder` stores the owner's order for Artists, Albums, Songs,
Folders, Playlists, and Search. `GLSettings.tabBarItems` stores up to five of
those identifiers, in that order. The Tab Bar settings list uses UIKit's row
reordering controls and checkmarks; tab rebuilding is deferred until leaving
Settings so changing a checkmark does not navigate away from the list.
`GLAppDelegate` reuses navigation stacks for destinations that remain visible.
Omitted destinations stay accessible through the top-right More button. Its
pushed list contains omitted library destinations, Upload, and Settings; the
global Search screen filters tracks by title, artist, or album. The Songs root
adds a Shuffle action alongside More in the right navigation items; it starts
shuffled playback of all library tracks, independent of the active search.

## Files

```
src/core/      code with no UIKit. The tests run it on the Mac and on the phone.
  GLTags         reads the tags and the art of a file
  GLMP3          reads the length of an MP3 file from its header
  GLLibrary      the SQLite index, the playlists, and the play counts
  GLScanner      makes the index agree with the files
  GLM3U          reads M3U playlists
  GLPlayQueue    the queue, shuffle, and repeat
  GLRenderer     joins the tracks with no gap
  GLReplayGain   the gain factor and the gain decoder
  GLArtCache     the copies of the art
  GLUploadServer the Wi-Fi upload page
  GLImport       moves a file from another app into the library
  GLDelete       deletes files and folders
  GLLink         reads groovelet:// links
src/audio/     the decoders, the AudioQueue player, and the background scan
src/ui/        the screens and the playback controller
src/ffmpeg/    a compiler builtin that FFmpeg needs on iOS 6
tests/         the tests of src/core and src/audio
probe/         tools that run on the phone: screenshot, CPU, and library speed
scripts/       build, test, install, package, toolchain, and sample music
resources/     Info.plist, the icons, the launch images, the tab icons, the font
packaging/     the files of the Cydia package
```

## The SDK

The app targets armv7/iOS 5.1 with the iOS 9.3 SDK. The tested Linux workflow
uses Clang/LLVM 21 and the pinned cctools-port linker produced by
`scripts/toolchain.sh`; see [`ios-5.1-backport.md`](ios-5.1-backport.md) for
recovery and install instructions. `fix-sdk.sh` changes the SDK stubs:

- It removes the simulator architectures, so that the new linker accepts the
  stubs.
- It moves the URL loading classes into the Foundation stub, where iOS 6 has
  them.
- It adds the C string functions to the libsystem_c stub, where iOS 6 has
  them.

`build.sh` stops the build when code uses an API that is newer than iOS 6.
