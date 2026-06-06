# status_helper — Design Spec

**Date:** 2026-06-06
**Status:** Approved (brainstorming)
**Platform:** Android only
**Stack:** Flutter (Material 3), Dart core, on-device FFmpeg
**License:** GPL (open-source / personal)

## 1. Problem

Posting a video to WhatsApp status frequently fails with:
- *"video limit is 90s"*
- *"only supports 3GP and MPEG4 video formats"*

The real cause: the video isn't an **MP4 with H.264 video + AAC audio**. Modern phones
record in HEVC/H.265 and downloads arrive as MKV/WebM/AV1/MOV — all rejected. The
length error is a separate, hard cap per platform.

`status_helper` takes any video and makes it postable as a status.

## 2. v1 Scope

In scope:
1. **Format conversion** — transcode any input (HEVC, AV1, VP9, MKV, WebM, MOV…) to
   MP4 (H.264 + AAC). If the video stream is already H.264, stream-copy (`-c copy`) to
   stay fast and skip the encoder.
2. **Length handling** — when a video exceeds the target's limit, the user chooses one:
   - **Split** into back-to-back parts (each ≤ limit), saved/shared as a numbered set.
   - **Trim** to a chosen window via a range slider.
   - **Speed up** to fit — offered only when the speed factor stays ≤ 1.5× (above that
     it looks comical); otherwise greyed out with a hint to split/trim.
3. **Multi-platform presets** — as a limits table only (WhatsApp 90s, Instagram 60s,
   etc.) that drives the length logic.

Output: always **save the result to a public gallery folder** AND offer **one-tap share**
to the chosen target app.

### Out of scope (v2+)
- Per-platform crop / aspect-ratio reframing (9:16) and size compression
- Image fixing
- Reading other apps' status folders
- iOS
- Hybrid MediaCodec encoder (see §7)

## 3. Architecture

Thin Material 3 UI over a pure-Dart core that drives FFmpeg. All video *decision logic*
is UI-free and device-free, so it is unit-testable. FFmpeg is quarantined behind a single
runner.

```
lib/
├── main.dart                      # app entry, Material 3 theme
├── presets/
│   └── platform_presets.dart      # limits table: WhatsApp 90s, IG 60s, ...
├── core/
│   ├── media_probe.dart           # ffprobe → MediaInfo (codec, duration, res, audio)
│   ├── compatibility.dart         # MediaInfo + Preset → FixPlan (pure, no FFmpeg)
│   ├── ffmpeg_runner.dart         # builds & runs FFmpeg commands, emits progress
│   ├── length_resolver.dart       # split / trim / speed → FFmpeg arg sets (pure)
│   └── job.dart                   # ConversionJob: input, plan, outputs, status
├── services/
│   ├── file_service.dart          # pick input, save to gallery folder
│   └── share_service.dart         # share-sheet / targeted intent
└── ui/
    ├── home_screen.dart           # pick a video, choose target app
    ├── plan_screen.dart           # detected issues + length-strategy choices
    ├── progress_screen.dart       # live progress %, cancel
    └── result_screen.dart         # preview, save-to-gallery, share
```

### Component contracts
- **`media_probe`** — in: file path; out: `MediaInfo`. Knows nothing about any platform.
- **`compatibility`** — in: `MediaInfo` + `Preset`; out: `FixPlan` (needs transcode?
  over length by how much?). Pure function.
- **`length_resolver`** — in: strategy + duration + limit; out: concrete FFmpeg
  operation(s), including part count, trim window, or speed factor with the 1.5× cap.
  Pure function.
- **`ffmpeg_runner`** — the only place that touches `ffmpeg_kit`. Runs operations,
  streams progress %.

### Packages
- A maintained `ffmpeg_kit_flutter` fork, **`-gpl` variant** (includes `libx264`).
- `file_picker` / `image_picker` — input selection.
- `share_plus` — output share sheet / targeted intent.
- `gal` or `media_store_plus` — save to a public gallery folder.

## 4. Data Flow (user journey)

1. **Home** → pick video, choose target app (WhatsApp default).
2. **Probe** → `media_probe` reads file; `compatibility` produces a `FixPlan`.
3. **Plan screen** shows plain-language findings:
   - Format: *"HEVC → will convert to H.264"* or *"Already compatible"*.
   - Length: if over limit, the split / trim / speed chooser (speed greyed when > 1.5×).
4. **Process** → `ffmpeg_runner` executes; `progress_screen` shows % and **Cancel**.
5. **Result** → preview output(s); split shows Part 1/2/3 list. Buttons: **Save to
   gallery** (also auto-saved) and **Share** → target app's share sheet with file(s).

## 5. Error Handling

- **Unreadable / corrupt file** → probe fails → friendly "Couldn't read this video".
- **Undecodable input** → runner reports decode error → "This file can't be converted"
  with raw reason behind a details expander.
- **FFmpeg non-zero exit** → surface the failed operation; keep any successfully produced
  split parts rather than discarding everything.
- **Cancelled job** → kill FFmpeg session, delete partial outputs, return to plan screen.
- **Gallery permission denied** → prompt; if denied, keep file in app-private storage and
  still allow Share.
- **Out of space** → estimate output size and warn before transcoding if it won't fit.

## 6. Testing

- **Pure unit tests** (no device/video) for `compatibility` (codec/length combos →
  correct `FixPlan`) and `length_resolver` (durations/limits → part counts, trim windows,
  speed factor + 1.5× cap). Most logic lives here, so most tests live here.
- **`ffmpeg_runner` tests** with a tiny bundled sample clip on a device/emulator: assert
  output is H.264/AAC, under limit; split produces N files each ≤ limit.
- **Widget tests** for `plan_screen`: given a `FixPlan`, correct choices render (speed-up
  greyed when overage large).
- **Manual smoke test**: real HEVC 4K clip end-to-end → posts to WhatsApp status without
  error.

## 7. Licensing Notes

- FFmpeg code is LGPL by default but becomes **GPL** when built with `libx264` (the H.264
  software encoder). v1 uses the `-gpl` build, so **the app is distributed under GPL**
  (source available). Consistent with the open-source/personal distribution choice.
- `-c copy` passthrough avoids x264 only when the input is already H.264; the core
  use-case (incompatible files) still requires the encoder.
- **Future closed-source path:** a hybrid engine — FFmpeg (LGPL) decode/demux +
  Android **MediaCodec** for H.264 encode — would avoid GPL and x264 patent exposure and
  add hardware-accelerated speed. The `ffmpeg_runner` encoder step is kept behind a clean
  interface so this swap is possible later without rewriting the decision logic. Deferred
  to v2.
- H.264 is patent-encumbered independent of software license; bundling x264 nominally
  makes the distributor responsible, vs. MediaCodec where the device maker has paid.

## 8. Key Decisions Log

| Decision | Choice |
|---|---|
| Scope vision | Universal status prep (multi-app presets) |
| v1 features | Format conversion + length handling only |
| Over-limit handling | User chooses split / trim / speed-up |
| Platforms | Android only |
| Output | Save to gallery + one-tap share |
| Engine | On-device FFmpeg (`-gpl`, x264) |
| Distribution | Open-source / personal (GPL) |
| UI | Standard Material 3, no custom design system |
