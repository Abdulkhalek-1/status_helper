# Status Helper

An Android app that makes any video postable as a WhatsApp (and similar apps') status.

Posting a status often fails with *"video limit is 90s"* or *"only supports 3GP and
MPEG4 video formats"*. The real cause is usually that the video isn't an **MP4 with
H.264 (8-bit) + AAC**, or it's over the platform's length limit. Status Helper fixes
both, entirely **on your device**.

## What it does

- **Format conversion** — transcodes any input (HEVC/H.265, AV1, VP9, MKV, WebM, MOV,
  10-bit H.264…) to a status-compatible **MP4 (H.264 High, 8-bit yuv420p + AAC)**.
  Already-compatible files are stream-copied for speed.
- **Length handling** — for videos over the target's limit, choose to **split** into
  back-to-back parts, **trim** to a window, or **speed up** to fit.
- **Target presets** — WhatsApp (90s), Instagram (60s), Facebook (90s), Telegram (60s).
- **Share-sheet integration** — share a video into Status Helper from any app, or pick
  one inside it.
- **"Convert anyway"** — force a safe re-encode if a target app still rejects the video.
- Saves the result to a *StatusHelper* gallery album and offers one-tap share.

Everything runs locally with on-device FFmpeg — **nothing is uploaded**. See
[PRIVACY.md](PRIVACY.md).

## Install

Download the APK for your phone from the [**Releases**](https://github.com/Abdulkhalek-1/status_helper/releases)
page and open it to install (you may need to allow "install from unknown sources").

- **Most phones:** `app-arm64-v8a-release.apk`
- Older 32-bit devices: `app-armeabi-v7a-release.apk`
- Emulators / x86_64: `app-x86_64-release.apk`

## Build from source

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.44+).

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

To run on a connected device/emulator: `flutter run`.

## Tech

Flutter (Material 3) · on-device FFmpeg (full-GPL build, libx264) · Android only.

## License

GPLv3 — see [LICENSE](LICENSE). The bundled FFmpeg + x264 components are GPL, so the
app is distributed under the GPL. You are free to use, study, modify, and share it.
