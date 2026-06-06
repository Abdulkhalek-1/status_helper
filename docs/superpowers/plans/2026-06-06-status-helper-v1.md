# status_helper v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An Android Flutter app that converts any video to a WhatsApp-compatible MP4 (H.264 + AAC) and resolves over-length videos via split / trim / speed-up, then saves to gallery and shares.

**Architecture:** A thin Material 3 UI over a pure-Dart core. The core is split into independently testable units: presets (data), media info parsing, compatibility analysis, length resolution, and FFmpeg command building — all pure Dart. FFmpeg execution and platform I/O (probe, file pick, gallery save, share) are quarantined behind thin wrapper classes. Most logic and most tests live in the pure core.

**Tech Stack:** Flutter (Material 3), Dart 3.12, `ffmpeg_kit_flutter_new` (full-GPL, includes libx264), `file_picker`, `share_plus`, `gal`.

---

## File Structure

```
lib/
├── main.dart                          # app entry, Material 3 theme, routes home
├── presets/
│   └── platform_presets.dart          # Preset model + const list (WhatsApp 90s, ...)
├── core/
│   ├── media_info.dart                # MediaInfo model + parseProbeJson() (pure)
│   ├── compatibility.dart             # FixPlan model + buildFixPlan() (pure)
│   ├── length_resolver.dart           # OutputOp model + split/trim/speed fns (pure)
│   ├── ffmpeg_command_builder.dart    # OutputOp + MediaInfo -> FFmpeg args (pure)
│   ├── media_probe.dart               # FFprobeKit wrapper -> MediaInfo (device)
│   └── ffmpeg_runner.dart             # runs commands, streams progress (device)
├── services/
│   ├── file_service.dart              # pick input, save output to gallery
│   └── share_service.dart             # share output file(s)
└── ui/
    ├── home_screen.dart               # pick video + choose target app
    ├── plan_screen.dart               # show FixPlan + length-strategy chooser
    ├── progress_screen.dart           # live % + cancel
    └── result_screen.dart             # preview, save, share

test/
├── presets/platform_presets_test.dart
├── core/media_info_test.dart
├── core/compatibility_test.dart
├── core/length_resolver_test.dart
├── core/ffmpeg_command_builder_test.dart
└── ui/plan_screen_test.dart
```

Delete the default `test/widget_test.dart` (it tests the counter scaffold we remove).

---

## Task 1: Dependencies & Android configuration

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/build.gradle.kts` (minSdk)
- Modify: `android/app/src/main/AndroidManifest.xml` (permissions)

- [ ] **Step 1: Add dependencies**

In `pubspec.yaml`, under `dependencies:` (after `cupertino_icons`), add:

```yaml
  ffmpeg_kit_flutter_new: ^4.2.1
  file_picker: ^8.1.2
  share_plus: ^10.1.2
  gal: ^2.3.0
  path_provider: ^2.1.4
  path: ^1.9.0
```

- [ ] **Step 2: Install**

Run: `flutter pub get`
Expected: "Got dependencies!" with no resolution errors.

- [ ] **Step 3: Set Android minSdk to 24**

`ffmpeg_kit_flutter_new` requires minSdk 24. In `android/app/build.gradle.kts`, inside `defaultConfig { ... }`, set:

```kotlin
        minSdk = 24
```

(Replace the existing `minSdk = flutter.minSdkVersion` line.)

- [ ] **Step 4: Add permissions**

In `android/app/src/main/AndroidManifest.xml`, add these lines inside `<manifest>` but above the `<application>` tag:

```xml
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="28" />
```

- [ ] **Step 5: Verify the project still builds**

Run: `flutter analyze`
Expected: No errors (the default counter app still compiles; warnings about unused demo code are acceptable for now).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml
git commit -m "chore: add ffmpeg/file/share deps and Android config"
```

---

## Task 2: Platform presets

**Files:**
- Create: `lib/presets/platform_presets.dart`
- Test: `test/presets/platform_presets_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:status_helper/presets/platform_presets.dart';

void main() {
  test('whatsapp preset has a 90 second limit', () {
    final whatsapp = kPresets.firstWhere((p) => p.id == 'whatsapp');
    expect(whatsapp.displayName, 'WhatsApp');
    expect(whatsapp.maxDuration, const Duration(seconds: 90));
  });

  test('all presets have unique ids and positive limits', () {
    final ids = kPresets.map((p) => p.id).toSet();
    expect(ids.length, kPresets.length);
    for (final p in kPresets) {
      expect(p.maxDuration > Duration.zero, isTrue);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presets/platform_presets_test.dart`
Expected: FAIL — `platform_presets.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
/// A target app's status constraints. v1 only models the length limit;
/// the compatible codecs (H.264/AAC in MP4) are the same across targets
/// and live in compatibility.dart.
class Preset {
  final String id;
  final String displayName;
  final Duration maxDuration;

  const Preset({
    required this.id,
    required this.displayName,
    required this.maxDuration,
  });
}

const List<Preset> kPresets = [
  Preset(id: 'whatsapp', displayName: 'WhatsApp', maxDuration: Duration(seconds: 90)),
  Preset(id: 'instagram', displayName: 'Instagram', maxDuration: Duration(seconds: 60)),
  Preset(id: 'facebook', displayName: 'Facebook', maxDuration: Duration(seconds: 90)),
  Preset(id: 'telegram', displayName: 'Telegram', maxDuration: Duration(seconds: 60)),
];

const Preset kDefaultPreset = kPresets[0];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presets/platform_presets_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presets/platform_presets.dart test/presets/platform_presets_test.dart
git commit -m "feat: add platform presets with length limits"
```

---

## Task 3: MediaInfo model + ffprobe JSON parser

**Files:**
- Create: `lib/core/media_info.dart`
- Test: `test/core/media_info_test.dart`

The parser is pure: it turns the JSON string FFprobe returns into a `MediaInfo`. This lets us test all parsing without a device.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:status_helper/core/media_info.dart';

const _hevcWithAudio = '''
{
  "streams": [
    {"codec_type": "video", "codec_name": "hevc", "width": 1920, "height": 1080},
    {"codec_type": "audio", "codec_name": "aac"}
  ],
  "format": {"duration": "125.400000", "format_name": "mov,mp4,m4a,3gp,3g2,mj2"}
}
''';

const _videoOnly = '''
{
  "streams": [
    {"codec_type": "video", "codec_name": "h264", "width": 720, "height": 1280}
  ],
  "format": {"duration": "30.0", "format_name": "mov,mp4"}
}
''';

void main() {
  test('parses codecs, duration and resolution', () {
    final info = parseProbeJson(_hevcWithAudio);
    expect(info.videoCodec, 'hevc');
    expect(info.audioCodec, 'aac');
    expect(info.duration, const Duration(milliseconds: 125400));
    expect(info.width, 1920);
    expect(info.height, 1080);
    expect(info.formatName, contains('mp4'));
  });

  test('audioCodec is null when there is no audio stream', () {
    final info = parseProbeJson(_videoOnly);
    expect(info.videoCodec, 'h264');
    expect(info.audioCodec, isNull);
  });

  test('throws FormatException when there is no video stream', () {
    const noVideo = '{"streams": [], "format": {"duration": "1.0"}}';
    expect(() => parseProbeJson(noVideo), throwsA(isA<FormatException>()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/media_info_test.dart`
Expected: FAIL — `media_info.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:convert';

/// Immutable description of a probed media file.
class MediaInfo {
  final String videoCodec;
  final String? audioCodec;
  final Duration duration;
  final int width;
  final int height;
  final String formatName;

  const MediaInfo({
    required this.videoCodec,
    required this.audioCodec,
    required this.duration,
    required this.width,
    required this.height,
    required this.formatName,
  });
}

/// Parses the JSON produced by `ffprobe -show_streams -show_format -of json`.
/// Throws [FormatException] if there is no video stream.
MediaInfo parseProbeJson(String jsonText) {
  final root = jsonDecode(jsonText) as Map<String, dynamic>;
  final streams = (root['streams'] as List).cast<Map<String, dynamic>>();

  final video = streams.firstWhere(
    (s) => s['codec_type'] == 'video',
    orElse: () => throw const FormatException('No video stream found'),
  );
  final audio = streams.where((s) => s['codec_type'] == 'audio').toList();

  final format = (root['format'] as Map<String, dynamic>?) ?? const {};
  final seconds = double.tryParse('${format['duration']}') ?? 0.0;

  return MediaInfo(
    videoCodec: '${video['codec_name']}',
    audioCodec: audio.isEmpty ? null : '${audio.first['codec_name']}',
    duration: Duration(milliseconds: (seconds * 1000).round()),
    width: (video['width'] as num?)?.toInt() ?? 0,
    height: (video['height'] as num?)?.toInt() ?? 0,
    formatName: '${format['format_name'] ?? ''}',
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/media_info_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/media_info.dart test/core/media_info_test.dart
git commit -m "feat: add MediaInfo model and ffprobe JSON parser"
```

---

## Task 4: Compatibility analysis (FixPlan)

**Files:**
- Create: `lib/core/compatibility.dart`
- Test: `test/core/compatibility_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:status_helper/core/media_info.dart';
import 'package:status_helper/core/compatibility.dart';
import 'package:status_helper/presets/platform_presets.dart';

MediaInfo _info({
  String video = 'h264',
  String? audio = 'aac',
  int seconds = 30,
}) =>
    MediaInfo(
      videoCodec: video,
      audioCodec: audio,
      duration: Duration(seconds: seconds),
      width: 720,
      height: 1280,
      formatName: 'mov,mp4',
    );

const _whatsapp = Preset(
  id: 'whatsapp',
  displayName: 'WhatsApp',
  maxDuration: Duration(seconds: 90),
);

void main() {
  test('compatible short h264/aac needs no fix', () {
    final plan = buildFixPlan(_info(), _whatsapp);
    expect(plan.needsVideoTranscode, isFalse);
    expect(plan.needsAudioTranscode, isFalse);
    expect(plan.isOverLength, isFalse);
    expect(plan.needsAnyFix, isFalse);
  });

  test('hevc video flags a video transcode', () {
    final plan = buildFixPlan(_info(video: 'hevc'), _whatsapp);
    expect(plan.needsVideoTranscode, isTrue);
    expect(plan.needsAnyFix, isTrue);
  });

  test('non-aac audio flags an audio transcode', () {
    final plan = buildFixPlan(_info(audio: 'opus'), _whatsapp);
    expect(plan.needsAudioTranscode, isTrue);
  });

  test('missing audio needs no audio transcode', () {
    final plan = buildFixPlan(_info(audio: null), _whatsapp);
    expect(plan.needsAudioTranscode, isFalse);
  });

  test('over-length is detected with the overage', () {
    final plan = buildFixPlan(_info(seconds: 150), _whatsapp);
    expect(plan.isOverLength, isTrue);
    expect(plan.overBy, const Duration(seconds: 60));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/compatibility_test.dart`
Expected: FAIL — `compatibility.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'media_info.dart';
import '../presets/platform_presets.dart';

/// Codecs/container WhatsApp and similar status uploaders accept.
const String kTargetVideoCodec = 'h264';
const String kTargetAudioCodec = 'aac';

/// A summary of what must change to make a file postable. Pure data.
class FixPlan {
  final bool needsVideoTranscode;
  final bool needsAudioTranscode;
  final bool isOverLength;
  final Duration duration;
  final Duration limit;

  const FixPlan({
    required this.needsVideoTranscode,
    required this.needsAudioTranscode,
    required this.isOverLength,
    required this.duration,
    required this.limit,
  });

  Duration get overBy => duration > limit ? duration - limit : Duration.zero;
  bool get needsAnyTranscode => needsVideoTranscode || needsAudioTranscode;
  bool get needsAnyFix => needsAnyTranscode || isOverLength;
}

FixPlan buildFixPlan(MediaInfo info, Preset preset) {
  return FixPlan(
    needsVideoTranscode: info.videoCodec != kTargetVideoCodec,
    needsAudioTranscode:
        info.audioCodec != null && info.audioCodec != kTargetAudioCodec,
    isOverLength: info.duration > preset.maxDuration,
    duration: info.duration,
    limit: preset.maxDuration,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/compatibility_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/compatibility.dart test/core/compatibility_test.dart
git commit -m "feat: add compatibility analysis producing FixPlan"
```

---

## Task 5: Length resolver (split / trim / speed → OutputOps)

**Files:**
- Create: `lib/core/length_resolver.dart`
- Test: `test/core/length_resolver_test.dart`

`OutputOp` is the single contract the command builder consumes: one op = one output file.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:status_helper/core/length_resolver.dart';

void main() {
  const limit = Duration(seconds: 90);

  test('passthrough produces one default op', () {
    final ops = passthroughOps();
    expect(ops, hasLength(1));
    expect(ops.single.startOffset, isNull);
    expect(ops.single.clipDuration, isNull);
    expect(ops.single.speedFactor, 1.0);
  });

  test('split of 200s into 90s limit yields 3 parts', () {
    final ops = splitOps(const Duration(seconds: 200), limit);
    expect(ops, hasLength(3));
    expect(ops[0].startOffset, Duration.zero);
    expect(ops[0].clipDuration, limit);
    expect(ops[1].startOffset, limit);
    expect(ops[2].startOffset, const Duration(seconds: 180));
    expect(ops[2].clipDuration, const Duration(seconds: 20));
    expect(ops.map((o) => o.suffix), ['_part1', '_part2', '_part3']);
  });

  test('trim yields one clip at the chosen start, capped at limit', () {
    final ops = trimOps(const Duration(seconds: 30), limit);
    expect(ops, hasLength(1));
    expect(ops.single.startOffset, const Duration(seconds: 30));
    expect(ops.single.clipDuration, limit);
  });

  test('speed-up is allowed when factor <= 1.5', () {
    expect(canSpeedUp(const Duration(seconds: 120), limit), isTrue); // 1.33x
    final ops = speedUpOps(const Duration(seconds: 120), limit);
    expect(ops.single.speedFactor, closeTo(120 / 90, 0.0001));
  });

  test('speed-up is disallowed when factor > 1.5', () {
    expect(canSpeedUp(const Duration(seconds: 200), limit), isFalse); // 2.22x
    expect(() => speedUpOps(const Duration(seconds: 200), limit),
        throwsA(isA<ArgumentError>()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/length_resolver_test.dart`
Expected: FAIL — `length_resolver.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
/// The three over-length strategies offered to the user.
enum LengthStrategy { split, trim, speedUp }

/// Above this factor, sped-up video looks comical, so speed-up is disallowed.
const double kMaxSpeedFactor = 1.5;

/// One output the runner must produce. A passthrough/whole-file op leaves
/// startOffset and clipDuration null and speedFactor at 1.0.
class OutputOp {
  final Duration? startOffset; // FFmpeg -ss
  final Duration? clipDuration; // FFmpeg -t
  final double speedFactor; // 1.0 = unchanged
  final String suffix; // appended to the output filename

  const OutputOp({
    this.startOffset,
    this.clipDuration,
    this.speedFactor = 1.0,
    this.suffix = '',
  });

  bool get clipsTime => startOffset != null || clipDuration != null;
  bool get changesSpeed => speedFactor != 1.0;
}

List<OutputOp> passthroughOps() => const [OutputOp()];

List<OutputOp> splitOps(Duration total, Duration limit) {
  final ops = <OutputOp>[];
  var start = Duration.zero;
  var index = 1;
  while (start < total) {
    final remaining = total - start;
    final part = remaining < limit ? remaining : limit;
    ops.add(OutputOp(
      startOffset: start,
      clipDuration: part,
      suffix: '_part$index',
    ));
    start += limit;
    index++;
  }
  return ops;
}

List<OutputOp> trimOps(Duration start, Duration limit) =>
    [OutputOp(startOffset: start, clipDuration: limit)];

bool canSpeedUp(Duration total, Duration limit) =>
    total.inMilliseconds / limit.inMilliseconds <= kMaxSpeedFactor;

List<OutputOp> speedUpOps(Duration total, Duration limit) {
  final factor = total.inMilliseconds / limit.inMilliseconds;
  if (factor > kMaxSpeedFactor) {
    throw ArgumentError('Speed factor $factor exceeds $kMaxSpeedFactor');
  }
  return [OutputOp(speedFactor: factor)];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/length_resolver_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/length_resolver.dart test/core/length_resolver_test.dart
git commit -m "feat: add length resolver producing OutputOps"
```

---

## Task 6: FFmpeg command builder

**Files:**
- Create: `lib/core/ffmpeg_command_builder.dart`
- Test: `test/core/ffmpeg_command_builder_test.dart`

Pure function: `MediaInfo + OutputOp + paths -> List<String>` of FFmpeg arguments. Rules:
- Re-encode video (`libx264`) when codec isn't h264, OR the op clips time, OR it changes speed; otherwise `-c:v copy`.
- Re-encode audio (`aac`) when codec isn't aac OR speed changes; otherwise copy. No audio → `-an`.
- Speed: `setpts=PTS/{f}` for video and `atempo={f}` for audio.
- Always output `.mp4` with `-movflags +faststart`, `-pix_fmt yuv420p` when encoding video.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:status_helper/core/media_info.dart';
import 'package:status_helper/core/length_resolver.dart';
import 'package:status_helper/core/ffmpeg_command_builder.dart';

MediaInfo _info({String video = 'h264', String? audio = 'aac'}) => MediaInfo(
      videoCodec: video,
      audioCodec: audio,
      duration: const Duration(seconds: 30),
      width: 720,
      height: 1280,
      formatName: 'mov,mp4',
    );

void main() {
  test('compatible passthrough copies both streams', () {
    final args =
        buildFfmpegArgs(_info(), const OutputOp(), '/in.mp4', '/out.mp4');
    expect(args, containsAllInOrder(['-i', '/in.mp4']));
    expect(args, containsAllInOrder(['-c:v', 'copy']));
    expect(args, containsAllInOrder(['-c:a', 'copy']));
    expect(args.last, '/out.mp4');
  });

  test('hevc input re-encodes video with libx264', () {
    final args = buildFfmpegArgs(
        _info(video: 'hevc'), const OutputOp(), '/in.mkv', '/out.mp4');
    expect(args, containsAllInOrder(['-c:v', 'libx264']));
    expect(args, containsAllInOrder(['-pix_fmt', 'yuv420p']));
  });

  test('clipping op re-encodes video and sets -ss/-t after -i', () {
    const op = OutputOp(
        startOffset: Duration(seconds: 10), clipDuration: Duration(seconds: 90));
    final args = buildFfmpegArgs(_info(), op, '/in.mp4', '/out.mp4');
    final iIndex = args.indexOf('-i');
    final ssIndex = args.indexOf('-ss');
    expect(ssIndex, greaterThan(iIndex)); // accurate seek: -ss after -i
    expect(args, containsAllInOrder(['-ss', '10']));
    expect(args, containsAllInOrder(['-t', '90']));
    expect(args, containsAllInOrder(['-c:v', 'libx264']));
  });

  test('speed-up adds setpts and atempo filters', () {
    const op = OutputOp(speedFactor: 1.25);
    final args = buildFfmpegArgs(_info(), op, '/in.mp4', '/out.mp4');
    expect(args, containsAllInOrder(['-filter:v', 'setpts=PTS/1.25']));
    expect(args, containsAllInOrder(['-filter:a', 'atempo=1.25']));
  });

  test('no audio stream produces -an and no audio codec flags', () {
    final args = buildFfmpegArgs(
        _info(audio: null), const OutputOp(), '/in.mp4', '/out.mp4');
    expect(args, contains('-an'));
    expect(args, isNot(contains('-c:a')));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/ffmpeg_command_builder_test.dart`
Expected: FAIL — `ffmpeg_command_builder.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'media_info.dart';
import 'length_resolver.dart';
import 'compatibility.dart';

/// Formats a Duration as seconds with millisecond precision, trimming
/// trailing zeros (e.g. 10, 90, 12.5).
String _secs(Duration d) {
  final s = d.inMilliseconds / 1000.0;
  return s == s.roundToDouble() ? s.round().toString() : s.toString();
}

/// Formats a speed factor without trailing zeros (1.25, 1.5).
String _factor(double f) =>
    f == f.roundToDouble() ? f.round().toString() : f.toString();

/// Builds the full FFmpeg argument list for one [OutputOp].
List<String> buildFfmpegArgs(
  MediaInfo info,
  OutputOp op,
  String inputPath,
  String outputPath,
) {
  final args = <String>['-y', '-i', inputPath];

  // Accurate seek/clip: -ss and -t AFTER -i.
  if (op.startOffset != null) {
    args.addAll(['-ss', _secs(op.startOffset!)]);
  }
  if (op.clipDuration != null) {
    args.addAll(['-t', _secs(op.clipDuration!)]);
  }

  final reencodeVideo =
      info.videoCodec != kTargetVideoCodec || op.clipsTime || op.changesSpeed;
  final hasAudio = info.audioCodec != null;
  final reencodeAudio =
      hasAudio && (info.audioCodec != kTargetAudioCodec || op.changesSpeed);

  // Video.
  if (op.changesSpeed) {
    args.addAll(['-filter:v', 'setpts=PTS/${_factor(op.speedFactor)}']);
  }
  if (reencodeVideo) {
    args.addAll(['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
      '-pix_fmt', 'yuv420p']);
  } else {
    args.addAll(['-c:v', 'copy']);
  }

  // Audio.
  if (!hasAudio) {
    args.add('-an');
  } else {
    if (op.changesSpeed) {
      args.addAll(['-filter:a', 'atempo=${_factor(op.speedFactor)}']);
    }
    if (reencodeAudio) {
      args.addAll(['-c:a', 'aac', '-b:a', '128k']);
    } else {
      args.addAll(['-c:a', 'copy']);
    }
  }

  args.addAll(['-movflags', '+faststart']);
  args.add(outputPath);
  return args;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/ffmpeg_command_builder_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Run the whole pure-core suite**

Run: `flutter test test/presets test/core`
Expected: PASS (all tasks 2–6).

- [ ] **Step 6: Commit**

```bash
git add lib/core/ffmpeg_command_builder.dart test/core/ffmpeg_command_builder_test.dart
git commit -m "feat: add FFmpeg command builder"
```

---

## Task 7: Media probe wrapper

**Files:**
- Create: `lib/core/media_probe.dart`

This is a thin device wrapper around FFprobeKit that delegates parsing to the (already tested) `parseProbeJson`. No unit test — it requires native FFprobe; it is exercised by the manual smoke test in Task 13.

- [ ] **Step 1: Write the implementation**

```dart
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'media_info.dart';

/// Probes [path] with FFprobe and returns parsed [MediaInfo].
/// Throws [FormatException] if the file cannot be read or has no video.
Future<MediaInfo> probeMedia(String path) async {
  final session = await FFprobeKit.execute(
    '-v quiet -print_format json -show_streams -show_format "$path"',
  );
  final rc = await session.getReturnCode();
  if (!ReturnCode.isSuccess(rc)) {
    throw const FormatException('Could not read this video');
  }
  final output = await session.getOutput() ?? '';
  if (output.trim().isEmpty) {
    throw const FormatException('Could not read this video');
  }
  return parseProbeJson(output);
}
```

- [ ] **Step 2: Verify it analyzes cleanly**

Run: `flutter analyze lib/core/media_probe.dart`
Expected: No errors. (If the import path differs in the installed version, run
`find ~/.pub-cache -path '*ffmpeg_kit_flutter_new*/lib/ffprobe_kit.dart'` to confirm the
package's public API path and adjust the import.)

- [ ] **Step 3: Commit**

```bash
git add lib/core/media_probe.dart
git commit -m "feat: add FFprobe media probe wrapper"
```

---

## Task 8: FFmpeg runner

**Files:**
- Create: `lib/core/ffmpeg_runner.dart`
- Create: `lib/core/job.dart`

Runs a list of `OutputOp`s, producing one output file each, streaming a 0.0–1.0 progress value and supporting cancellation. Device-only; exercised by Task 13's smoke test.

- [ ] **Step 1: Write the job model**

Create `lib/core/job.dart`:

```dart
import 'media_info.dart';
import 'length_resolver.dart';

/// Everything needed to run a conversion and report results.
class ConversionJob {
  final String inputPath;
  final MediaInfo info;
  final List<OutputOp> ops;
  final String outputDir;
  final String baseName; // output filename without suffix or extension

  const ConversionJob({
    required this.inputPath,
    required this.info,
    required this.ops,
    required this.outputDir,
    required this.baseName,
  });
}
```

- [ ] **Step 2: Write the runner**

Create `lib/core/ffmpeg_runner.dart`:

```dart
import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path/path.dart' as p;
import 'job.dart';
import 'ffmpeg_command_builder.dart';

/// Runs a [ConversionJob], writing one MP4 per OutputOp.
class FfmpegRunner {
  FFmpegSession? _session;
  bool _cancelled = false;

  /// Runs all ops. [onProgress] reports overall 0.0–1.0 across all ops.
  /// Returns the produced output file paths. Throws [Exception] on failure.
  /// On cancellation, deletes partial outputs and returns an empty list.
  Future<List<String>> run(
    ConversionJob job, {
    void Function(double progress)? onProgress,
  }) async {
    _cancelled = false;
    final outputs = <String>[];
    final totalMs = job.ops.fold<int>(
      0,
      (sum, op) => sum + _opDurationMs(job, op),
    );
    var completedMs = 0;

    for (final op in job.ops) {
      if (_cancelled) break;
      final outPath = p.join(job.outputDir, '${job.baseName}${op.suffix}.mp4');
      final args = buildFfmpegArgs(job.info, op, job.inputPath, outPath);
      final opMs = _opDurationMs(job, op);

      final completer = Completer<bool>();
      _session = await FFmpegKit.executeWithArgumentsAsync(
        args,
        (session) async {
          final rc = await session.getReturnCode();
          completer.complete(ReturnCode.isSuccess(rc));
        },
        (Statistics s) {
          if (opMs > 0) {
            final frac = (s.getTime() / opMs).clamp(0.0, 1.0);
            onProgress?.call(((completedMs + frac * opMs) / totalMs)
                .clamp(0.0, 1.0));
          }
        },
      );

      final ok = await completer.future;
      if (_cancelled) {
        _deleteQuietly(outPath);
        break;
      }
      if (!ok) {
        // Keep any earlier successful parts; surface this failure.
        throw Exception('Conversion failed for ${op.suffix.isEmpty ? "video" : op.suffix}');
      }
      outputs.add(outPath);
      completedMs += opMs;
      onProgress?.call((completedMs / totalMs).clamp(0.0, 1.0));
    }

    if (_cancelled) {
      for (final o in outputs) {
        _deleteQuietly(o);
      }
      return [];
    }
    return outputs;
  }

  Future<void> cancel() async {
    _cancelled = true;
    await FFmpegKit.cancel();
  }

  int _opDurationMs(ConversionJob job, OutputOp op) {
    final base = op.clipDuration ?? job.info.duration;
    final ms = op.changesSpeed
        ? (base.inMilliseconds / op.speedFactor).round()
        : base.inMilliseconds;
    return ms;
  }

  void _deleteQuietly(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}
```

- [ ] **Step 3: Verify it analyzes cleanly**

Run: `flutter analyze lib/core/ffmpeg_runner.dart lib/core/job.dart`
Expected: No errors. (If any FFmpegKit import path differs, confirm with
`find ~/.pub-cache -path '*ffmpeg_kit_flutter_new*/lib/*.dart'` and adjust.)

- [ ] **Step 4: Commit**

```bash
git add lib/core/ffmpeg_runner.dart lib/core/job.dart
git commit -m "feat: add FFmpeg runner with progress and cancel"
```

---

## Task 9: File and share services

**Files:**
- Create: `lib/services/file_service.dart`
- Create: `lib/services/share_service.dart`

Thin wrappers around `file_picker`, `path_provider`, `gal`, and `share_plus`. Device-only; exercised by Task 13.

- [ ] **Step 1: Write the file service**

Create `lib/services/file_service.dart`:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class FileService {
  /// Opens the system picker; returns the chosen video path or null.
  Future<String?> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    return result?.files.single.path;
  }

  /// A private working directory for intermediate outputs.
  Future<String> workingDir() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  /// Saves a produced video file to the public gallery.
  /// Throws if permission is denied (caller falls back to share-only).
  Future<void> saveToGallery(String path) async {
    await Gal.putVideo(path, album: 'StatusHelper');
  }

  /// Whether gallery access is currently granted.
  Future<bool> hasGalleryAccess() => Gal.hasAccess();

  /// Requests gallery access; returns whether it was granted.
  Future<bool> requestGalleryAccess() => Gal.requestAccess();
}
```

- [ ] **Step 2: Write the share service**

Create `lib/services/share_service.dart`:

```dart
import 'package:share_plus/share_plus.dart';

class ShareService {
  /// Opens the system share sheet with the produced file(s).
  /// The user picks WhatsApp/Instagram/etc. from the sheet (the most reliable
  /// cross-app path on Android; a targeted intent is a v2 enhancement).
  Future<void> shareFiles(List<String> paths) async {
    await Share.shareXFiles(paths.map((p) => XFile(p)).toList());
  }
}
```

- [ ] **Step 3: Verify analysis**

Run: `flutter analyze lib/services`
Expected: No errors. (If `Share.shareXFiles` is deprecated in the installed
share_plus, use the documented `SharePlus.instance.share(ShareParams(files: ...))`
form shown in that version's README.)

- [ ] **Step 4: Commit**

```bash
git add lib/services/file_service.dart lib/services/share_service.dart
git commit -m "feat: add file and share services"
```

---

## Task 10: Home screen

**Files:**
- Create: `lib/ui/home_screen.dart`

Lets the user pick a target preset and a video, probes it, builds the FixPlan, and
navigates to the plan screen.

- [ ] **Step 1: Write the implementation**

```dart
import 'package:flutter/material.dart';
import '../presets/platform_presets.dart';
import '../core/media_probe.dart';
import '../core/compatibility.dart';
import '../services/file_service.dart';
import 'plan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fileService = FileService();
  Preset _preset = kDefaultPreset;
  bool _busy = false;

  Future<void> _pickAndAnalyze() async {
    setState(() => _busy = true);
    try {
      final path = await _fileService.pickVideo();
      if (path == null) return;
      final info = await probeMedia(path);
      final plan = buildFixPlan(info, _preset);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlanScreen(
          inputPath: path,
          info: info,
          plan: plan,
          preset: _preset,
        ),
      ));
    } on FormatException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Something went wrong reading that video.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('status_helper')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Make any video postable as a status.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            DropdownButtonFormField<Preset>(
              initialValue: _preset,
              decoration: const InputDecoration(
                labelText: 'Target app',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final p in kPresets)
                  DropdownMenuItem(value: p, child: Text(p.displayName)),
              ],
              onChanged: _busy
                  ? null
                  : (p) => setState(() => _preset = p ?? _preset),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _pickAndAnalyze,
              icon: const Icon(Icons.video_library),
              label: Text(_busy ? 'Analyzing…' : 'Pick a video'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analysis**

Run: `flutter analyze lib/ui/home_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/home_screen.dart
git commit -m "feat: add home screen with preset + video pick"
```

---

## Task 11: Plan screen (with widget test)

**Files:**
- Create: `lib/ui/plan_screen.dart`
- Test: `test/ui/plan_screen_test.dart`

Shows the findings and, when over-length, the strategy chooser. Speed-up is disabled
when `canSpeedUp` is false. Builds the `OutputOp`s and a `ConversionJob`, then navigates
to the progress screen.

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:status_helper/core/media_info.dart';
import 'package:status_helper/core/compatibility.dart';
import 'package:status_helper/presets/platform_presets.dart';
import 'package:status_helper/ui/plan_screen.dart';

MediaInfo _info(int seconds) => MediaInfo(
      videoCodec: 'hevc',
      audioCodec: 'aac',
      duration: Duration(seconds: seconds),
      width: 720,
      height: 1280,
      formatName: 'mov,mp4',
    );

Widget _wrap(int seconds) {
  final info = _info(seconds);
  return MaterialApp(
    home: PlanScreen(
      inputPath: '/in.mp4',
      info: info,
      plan: buildFixPlan(info, kDefaultPreset),
      preset: kDefaultPreset,
    ),
  );
}

void main() {
  testWidgets('over by a lot disables speed-up', (tester) async {
    await tester.pumpWidget(_wrap(200)); // 2.22x
    final speedTile = tester.widget<RadioListTile<String>>(
      find.widgetWithText(RadioListTile<String>, 'Speed up to fit'),
    );
    expect(speedTile.onChanged, isNull); // disabled
  });

  testWidgets('modest overage enables speed-up', (tester) async {
    await tester.pumpWidget(_wrap(120)); // 1.33x
    final speedTile = tester.widget<RadioListTile<String>>(
      find.widgetWithText(RadioListTile<String>, 'Speed up to fit'),
    );
    expect(speedTile.onChanged, isNotNull); // enabled
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/plan_screen_test.dart`
Expected: FAIL — `plan_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:flutter/material.dart';
import '../core/media_info.dart';
import '../core/compatibility.dart';
import '../core/length_resolver.dart';
import '../core/job.dart';
import '../presets/platform_presets.dart';
import '../services/file_service.dart';
import 'progress_screen.dart';

class PlanScreen extends StatefulWidget {
  final String inputPath;
  final MediaInfo info;
  final FixPlan plan;
  final Preset preset;

  const PlanScreen({
    super.key,
    required this.inputPath,
    required this.info,
    required this.plan,
    required this.preset,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  LengthStrategy _strategy = LengthStrategy.split;
  Duration _trimStart = Duration.zero;

  bool get _canSpeed =>
      canSpeedUp(widget.info.duration, widget.preset.maxDuration);

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  List<OutputOp> _buildOps() {
    if (!widget.plan.isOverLength) return passthroughOps();
    switch (_strategy) {
      case LengthStrategy.split:
        return splitOps(widget.info.duration, widget.preset.maxDuration);
      case LengthStrategy.trim:
        return trimOps(_trimStart, widget.preset.maxDuration);
      case LengthStrategy.speedUp:
        return speedUpOps(widget.info.duration, widget.preset.maxDuration);
    }
  }

  Future<void> _start() async {
    final dir = await FileService().workingDir();
    final job = ConversionJob(
      inputPath: widget.inputPath,
      info: widget.info,
      ops: _buildOps(),
      outputDir: dir,
      baseName: 'status_${DateTime.now().millisecondsSinceEpoch}',
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProgressScreen(job: job)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final limit = widget.preset.maxDuration;
    final maxTrimStart = widget.info.duration > limit
        ? (widget.info.duration - limit)
        : Duration.zero;

    return Scaffold(
      appBar: AppBar(title: Text('Fix for ${widget.preset.displayName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _findingTile(
            icon: p.needsVideoTranscode ? Icons.build : Icons.check_circle,
            title: 'Format',
            subtitle: p.needsVideoTranscode
                ? '${widget.info.videoCodec.toUpperCase()} → will convert to H.264'
                : 'Already compatible',
          ),
          _findingTile(
            icon: p.isOverLength ? Icons.timer : Icons.check_circle,
            title: 'Length',
            subtitle: p.isOverLength
                ? '${_fmt(widget.info.duration)}, over the ${limit.inSeconds}s limit'
                : '${_fmt(widget.info.duration)}, within the limit',
          ),
          if (p.isOverLength) ...[
            const Divider(height: 32),
            Text('How should we shorten it?',
                style: Theme.of(context).textTheme.titleMedium),
            RadioListTile<String>(
              value: 'split',
              groupValue: _strategy.name,
              title: const Text('Split into parts'),
              subtitle: Text(
                  '${splitOps(widget.info.duration, limit).length} parts of ≤${limit.inSeconds}s'),
              onChanged: (_) =>
                  setState(() => _strategy = LengthStrategy.split),
            ),
            RadioListTile<String>(
              value: 'trim',
              groupValue: _strategy.name,
              title: const Text('Trim to a clip'),
              subtitle: Text(
                  'Keep ${limit.inSeconds}s starting at ${_fmt(_trimStart)}'),
              onChanged: (_) =>
                  setState(() => _strategy = LengthStrategy.trim),
            ),
            if (_strategy == LengthStrategy.trim && maxTrimStart > Duration.zero)
              Slider(
                value: _trimStart.inSeconds.toDouble(),
                max: maxTrimStart.inSeconds.toDouble(),
                divisions: maxTrimStart.inSeconds,
                label: _fmt(_trimStart),
                onChanged: (v) =>
                    setState(() => _trimStart = Duration(seconds: v.round())),
              ),
            RadioListTile<String>(
              value: 'speedUp',
              groupValue: _strategy.name,
              title: const Text('Speed up to fit'),
              subtitle: Text(_canSpeed
                  ? 'Slightly faster so it all fits'
                  : 'Too long to speed up watchably'),
              onChanged: _canSpeed
                  ? (_) => setState(() => _strategy = LengthStrategy.speedUp)
                  : null,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.auto_fix_high),
            label: Text(p.needsAnyFix ? 'Fix it' : 'Prepare for sharing'),
          ),
        ],
      ),
    );
  }

  Widget _findingTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/plan_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/plan_screen.dart test/ui/plan_screen_test.dart
git commit -m "feat: add plan screen with strategy chooser"
```

---

## Task 12: Progress screen

**Files:**
- Create: `lib/ui/progress_screen.dart`

Runs the job via `FfmpegRunner`, shows a live bar and Cancel, and on success navigates
to the result screen.

- [ ] **Step 1: Write the implementation**

```dart
import 'package:flutter/material.dart';
import '../core/ffmpeg_runner.dart';
import '../core/job.dart';
import 'result_screen.dart';

class ProgressScreen extends StatefulWidget {
  final ConversionJob job;
  const ProgressScreen({super.key, required this.job});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _runner = FfmpegRunner();
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final outputs = await _runner.run(
        widget.job,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      if (outputs.isEmpty) {
        Navigator.of(context).pop(); // cancelled
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(outputPaths: outputs)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _cancel() async {
    await _runner.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Working…')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error == null) ...[
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 16),
              Text('${(_progress * 100).round()}%'),
              const SizedBox(height: 24),
              OutlinedButton(onPressed: _cancel, child: const Text('Cancel')),
            ] else ...[
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analysis**

Run: `flutter analyze lib/ui/progress_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/progress_screen.dart
git commit -m "feat: add progress screen with cancel"
```

---

## Task 13: Result screen + app wiring + smoke test

**Files:**
- Create: `lib/ui/result_screen.dart`
- Modify: `lib/main.dart`
- Delete: `test/widget_test.dart`

- [ ] **Step 1: Write the result screen**

Create `lib/ui/result_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../services/file_service.dart';
import '../services/share_service.dart';

class ResultScreen extends StatefulWidget {
  final List<String> outputPaths;
  const ResultScreen({super.key, required this.outputPaths});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _fileService = FileService();
  final _shareService = ShareService();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _autoSave();
  }

  Future<void> _autoSave() async {
    try {
      if (!await _fileService.hasGalleryAccess()) {
        await _fileService.requestGalleryAccess();
      }
      for (final path in widget.outputPaths) {
        await _fileService.saveToGallery(path);
      }
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      _toast('Saved to app storage (gallery permission denied). You can still share.');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.outputPaths.length > 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Done')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: Icon(_saved ? Icons.check_circle : Icons.hourglass_bottom),
            title: Text(_saved ? 'Saved to gallery' : 'Saving to gallery…'),
            subtitle: Text(multi
                ? '${widget.outputPaths.length} parts ready — post them in order'
                : 'Your video is ready'),
          ),
          const Divider(),
          for (final path in widget.outputPaths)
            ListTile(
              leading: const Icon(Icons.movie),
              title: Text(p.basename(path)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _shareService.shareFiles(widget.outputPaths),
            icon: const Icon(Icons.share),
            label: Text(multi ? 'Share all parts' : 'Share'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Fix another video'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Rewrite main.dart**

Replace the entire contents of `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const StatusHelperApp());
}

class StatusHelperApp extends StatelessWidget {
  const StatusHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'status_helper',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
```

- [ ] **Step 3: Delete the stale default test**

Run: `rm test/widget_test.dart`

- [ ] **Step 4: Analyze and run the full unit suite**

Run: `flutter analyze`
Expected: No errors.

Run: `flutter test`
Expected: PASS — all pure-core and plan-screen tests green.

- [ ] **Step 5: Manual smoke test on a device/emulator**

This validates the device-only pieces (probe, runner, gallery, share) end-to-end.

1. Connect an Android device (API 24+) or start an emulator.
2. Run: `flutter run`
3. Pick a real **HEVC/H.265** video that's **over 90 seconds** (e.g. a recent phone recording).
4. Confirm the plan screen reports "HEVC → will convert to H.264" and "over the 90s limit".
5. Choose **Split**, tap **Fix it**, watch the progress bar advance, reach the result screen.
6. Confirm parts appear, "Saved to gallery" shows, and **Share** opens the system sheet.
7. Open WhatsApp, set the first part as your status — it should be accepted with no format/length error.

Record the result. If FFmpeg import paths or share/gallery APIs differ from this plan in the installed package versions, fix the import/call to match that version's README, re-run `flutter analyze`, and note the change in the commit.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/result_screen.dart lib/main.dart
git rm test/widget_test.dart
git commit -m "feat: add result screen, wire app, remove default test"
```

---

## Self-Review Notes

- **Spec coverage:** Format conversion (Tasks 3,4,6,7,8), length handling split/trim/speed (Tasks 5,6,11), presets table (Task 2), save-to-gallery + share (Tasks 9,13), error handling — unreadable/undecodable (Tasks 7,10), FFmpeg failure keeps earlier parts (Task 8), cancel deletes partials (Task 8), gallery permission fallback (Task 13). All v1 spec sections map to a task.
- **Out of scope confirmed absent:** no crop/compress, no image fixing, no iOS, no MediaCodec hybrid.
- **Type consistency:** `MediaInfo`, `FixPlan`, `OutputOp`, `ConversionJob`, `buildFixPlan`, `buildFfmpegArgs`, `splitOps/trimOps/speedUpOps/passthroughOps/canSpeedUp` are defined once and referenced consistently across tasks.
- **Known v1 trade-off:** clipping (split/trim) always re-encodes video for frame-accurate cuts rather than stream-copying — slower but avoids black-start keyframe artifacts. Documented in Task 6.
```
