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
///
/// Set [forceReencode] to re-encode video and audio to the WhatsApp-safe
/// baseline even when the streams look compatible — the "Convert anyway"
/// escape hatch for files rejected for reasons we can't detect.
List<String> buildFfmpegArgs(
  MediaInfo info,
  OutputOp op,
  String inputPath,
  String outputPath, {
  bool forceReencode = false,
}) {
  final args = <String>['-y', '-i', inputPath];

  // Accurate seek/clip: -ss and -t AFTER -i.
  if (op.startOffset != null) {
    args.addAll(['-ss', _secs(op.startOffset!)]);
  }
  if (op.clipDuration != null) {
    args.addAll(['-t', _secs(op.clipDuration!)]);
  }

  // A non-yuv420p (e.g. 10-bit) pixel format reads as "h264" but is rejected by
  // WhatsApp, and `-c:v copy` would preserve it, so it must force a re-encode.
  final badPixelFormat =
      info.pixelFormat != null && info.pixelFormat != kTargetPixelFormat;
  final reencodeVideo = forceReencode ||
      info.videoCodec != kTargetVideoCodec ||
      badPixelFormat ||
      op.clipsTime ||
      op.changesSpeed;
  final hasAudio = info.audioCodec != null;
  final reencodeAudio = hasAudio &&
      (forceReencode || info.audioCodec != kTargetAudioCodec || op.changesSpeed);

  // Video.
  if (op.changesSpeed) {
    args.addAll(['-filter:v', 'setpts=PTS/${_factor(op.speedFactor)}']);
  }
  if (reencodeVideo) {
    // Pin a WhatsApp-safe baseline: H.264 High@4.0, 8-bit yuv420p.
    args.addAll(['-c:v', 'libx264', '-profile:v', 'high', '-level', '4.0',
      '-preset', 'veryfast', '-crf', '23', '-pix_fmt', 'yuv420p']);
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
