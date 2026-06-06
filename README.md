# status_helper

An Android app that makes any video postable as a WhatsApp (and similar apps') status.

Posting a status often fails with *"video limit is 90s"* or *"only supports 3GP and
MPEG4 video formats"*. The real cause is that the video isn't an **MP4 with H.264 + AAC**,
or it's over the platform's length limit. `status_helper` fixes both, on-device.

## What it does (v1)

- **Format conversion** — transcode any input (HEVC, AV1, VP9, MKV, WebM, MOV…) to a
  compatible MP4 (H.264 + AAC). Already-compatible files are stream-copied (fast).
- **Length handling** — for videos over the limit, choose to **split** into parts,
  **trim** to a window, or **speed up** to fit.
- Saves the result to your gallery and offers one-tap share to the target app.

All processing happens **on your device** with FFmpeg — nothing is uploaded.

## Status

Early development. See the design spec in
[docs/superpowers/specs/](docs/superpowers/specs/).

## Tech

Flutter (Material 3) · on-device FFmpeg (`-gpl`/x264) · Android only.

## License

GPLv3 — see [LICENSE](LICENSE). (The bundled FFmpeg + x264 components are GPL, so the app
is distributed under the GPL.)
