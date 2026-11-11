# Equalizer feasibility: iOS 5.1.1 / iPod touch 3G

**Scope:** research and planning only. No playback integration has been made. Candidate compatibility and performance on the target device are not yet verified.

## Recommendation

An equalizer can fit Groovelet’s existing PCM path without replacing its decoders or AudioQueue. Use one stereo biquad-cascade engine for both a 10-band graphic EQ and parametric EQ. Process in floating point after ReplayGain and before final int16 conversion; retain state per track. First validate a small implementation or DSPFilters subset in isolation. Do not adopt miniaudio’s playback/decoding stack: Groovelet already provides those functions.

## Existing audio path

`docs/architecture.md` documents `file → decoder → gain → renderer → AudioQueue → output`.

- `src/core/GLDecoder.h`: decoder contract is 44.1 kHz, stereo, interleaved signed 16-bit PCM.
- `src/audio/GLAppleDecoder.m:27–36`: ExtAudioFile requests that PCM format.
- `src/audio/GLFFmpegDecoder.m:63–70`: FFmpeg resamples/converts to the same format.
- `src/core/GLReplayGain.m:3–15`: ReplayGain factor uses tagged gain/peak; lines 18–44 wrap a decoder, scale samples and clip to int16.
- `src/core/GLRenderer.m:98–130`: renderer fills output buffers and can start the next track within the same buffer; lines 134–146 map output frames to track/time.
- `src/audio/GLAudioPlayer.m:9–11,100–112,130–159`: AudioQueue outputs renderer PCM using four 8,192-frame buffers. Lines 214–229 pre-open the next decoder asynchronously.
- `build.sh:1–9,39–50`: Clang build targets `armv7-apple-ios5.1`, using ARM mode and the iOS 9.3 SDK.
- [`docs/ios-5.1-backport.md`](ios-5.1-backport.md): build and USB deployment instructions for the iOS 5.1.1 iPod touch 3G. The iOS 9.3 SDK is available locally but is not tracked by Git. Equalizer-specific DSP, CPU, and audio-quality validation on the iPod remain outstanding.

**Integration point:** a stateful EQ wrapper per track, after gain and before renderer consumption, is the least disruptive seam. Do not share one filter state across `GLRenderer` buffers: a buffer may cross track boundaries. Per-track state also makes seeking/reset behavior explicit. Synchronize settings for both current and prefetched decoders.

**Headroom caveat:** ReplayGain currently clips to int16 before the EQ. A later EQ cannot undo that clipping. Proper EQ boost/headroom therefore requires a float processing stage that combines gain and EQ, then quantizes/clips once at output. Bypass must remain bit-exact if preserving current playback behavior is required.

## DSP options

| Candidate | Evidence and fit | Cost / constraints | Assessment |
|---|---|---|---|
| [miniaudio](https://github.com/mackron/miniaudio) | C, single-source audio library; provides basic filters/effects and low-level APIs. README lists iOS and public-domain or MIT No Attribution licensing. | Broad playback/decoder framework is unnecessary here. Isolated filter code may be considered, but exact source/API fit is unverified. | Do not integrate the whole library. Candidate only for a proven minimal DSP component. |
| [DSPFilters](https://github.com/vinniefalco/DSPFilters) | MIT; README documents RBJ biquads, shelves, multichannel filters and smooth coefficient interpolation. Supports selective use, with no external DSP dependencies. | C++ templates and standard library. Must compile with project ARMv7/iOS 5.1 flags; not tested here. | Strongest documented library fit for graphic EQ and PEQ; isolate required sources and test update behavior. |
| [iir1](https://github.com/berndporr/iir1) | MIT repository metadata; header-oriented, sample-by-sample IIR, RBJ/shelf filters, custom coefficient import. | C++ templates; README describes exceptions for invalid setup unless disabled. Project lists desktop platforms, not iOS. | Compact alternative; target compatibility and smooth live updates need verification. |
| Native Core Audio | Groovelet already uses ExtAudioFile and AudioQueue (`src/audio/GLAudioPlayer.m`). | An Audio Unit effects route would mean more output-architecture work than processing Groovelet’s existing PCM. iOS 5.1 effect availability/behavior was not verified. | Not the simplest option. Keep AudioQueue and evaluate only if a concrete system effect meets requirements. |

All compatibility conclusions above are source-based. No isolated builds or device benchmarks were run. In particular, iOS/ARMv7 support claims do not prove compatibility with Groovelet’s exact old deployment target and toolchain.

## One engine, two EQ modes

- **10-band graphic:** ten fixed center frequencies; one peaking biquad per band; persist ten gain values in dB and define/document each band’s Q or bandwidth.
- **Parametric:** cascade peaking, low-shelf and high-shelf biquads; store type, frequency, gain and Q. Validate values and keep frequencies below the 22.05 kHz Nyquist limit.
- **Preamp/headroom:** keep samples in float (or double if measured affordable). Account for positive EQ gain with pre-attenuation; ReplayGain’s existing peak adjustment alone does not protect against EQ boosts.
- **Clipping:** quantize and saturate only at the end. A limiter is possible but adds complexity and changes sound; begin with gain/headroom management.
- **Live changes:** calculate coefficients off the audio callback, publish a complete immutable parameter set, and apply it at a safe buffer boundary. Avoid callback allocation, locks and filter design. Crossfade old/new cascades or use a verified stable interpolation method to avoid clicks.
- **Persistence:** store a versioned model (mode, enabled, preamp, bands/filters) and separately named custom presets. `src/core/GLSettings.m:48–51` shows the existing NSUserDefaults/notification pattern.

## Preset sources and rights

- [AutoEq](https://github.com/jaakkopasanen/AutoEq) generates settings for other equalizers; its README documents parametric and ten-band output. It is a settings/data source, not a runtime DSP engine. Its code is MIT ([LICENSE](https://github.com/jaakkopasanen/AutoEq/blob/master/LICENSE)), but the README names measurement data from multiple third parties. Check data provenance and redistribution terms independently before bundling measurements or generated presets.
- Equalizer APO text configurations are a potential import format for preamp and filter directives. Import should support a documented subset, validate numeric ranges, and reject/report unsupported commands. Exact format behavior was not verified for this report; confirm against current documentation and real sample files before implementation.
- Curated genre/music presets are subjective and have no single standard format. Do not redistribute another application’s preset collection without checking its permissions.
- Recommended order: define Groovelet’s own compact, versioned preset representation first; defer bulk data and external-format import until licensing and parser scope are resolved.

## Risks and verification required

1. **DSP load:** ten biquads × two channels × 44,100 samples/s is about 882,000 channel-sample filter updates per second (roughly 5.3 million multiply-accumulate operations/s for a conventional biquad). This is an estimate, not an iPod touch benchmark. Measure the target device with 10-band and realistic PEQ loads.
2. **PCM/headroom:** the current int16 ReplayGain wrapper clips before any proposed EQ. Test gain ordering, peak handling, unity bypass and final quantization.
3. **State and transitions:** test seeks, decoder restart, track changes inside one renderer buffer, and next-track prefetch. Ensure states are reset per track and live settings reach both current and queued decoders.
4. **Real-time safety:** the AudioQueue fill path reaches `GLRenderer`; avoid adding callback locks, allocations or Objective-C-heavy coefficient work.
5. **Behavior preservation:** regression-test gapless timing, playback clock/track spans, seek, ReplayGain modes, pause/resume and existing route/interruption behavior.
6. **Preset correctness and rights:** test malformed/out-of-range imports and verify licensing of each bundled dataset, not just the AutoEq code.

## Phased implementation plan (future work; not started)

1. Build an isolated 44.1 kHz stereo float-biquad prototype; verify unity and frequency response against reference calculations.
2. Compile DSPFilters/iir1 and any selected miniaudio DSP subset using `build.sh`’s ARMv7/iOS 5.1 flags. Benchmark on an actual iPod touch 3G. Neither check has been performed yet.
3. Select the smallest robust engine; specify ReplayGain/EQ/headroom ordering before touching playback code.
4. Integrate per-track processing, exact bypass, seek reset and safe live parameter updates; add tests for gapless/prefetched transitions.
5. Add graphic/parametric UI and versioned custom presets. Add external import only after format and licensing review.
6. Device-test CPU/battery/thermal behavior, artifacts, gapless playback, seeking, background audio, interruptions and route changes on iOS 5.1.1.

**Effort estimate:** basic ten-band EQ, bypass, persistence and tests: medium (about 3–5 engineering days). Ten-band plus PEQ, smooth updates, headroom and robust custom presets: medium-high (about 1–2 weeks). These estimates exclude device access, UI polish, and any Audio Unit redesign.
