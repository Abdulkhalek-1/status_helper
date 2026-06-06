import 'media_info.dart';
import '../presets/platform_presets.dart';

/// Codecs/container/pixel format WhatsApp and similar status uploaders accept.
const String kTargetVideoCodec = 'h264';
const String kTargetAudioCodec = 'aac';
const String kTargetPixelFormat = 'yuv420p'; // 8-bit; WhatsApp rejects 10-bit.

/// A summary of what must change to make a file postable. Pure data.
class FixPlan {
  final bool needsVideoTranscode;
  final bool needsAudioTranscode;

  /// Container isn't MP4 (e.g. mkv/webm/avi); needs a remux even if the codecs
  /// are already fine.
  final bool needsRemux;
  final bool isOverLength;
  final Duration duration;
  final Duration limit;

  const FixPlan({
    required this.needsVideoTranscode,
    required this.needsAudioTranscode,
    required this.needsRemux,
    required this.isOverLength,
    required this.duration,
    required this.limit,
  });

  Duration get overBy => duration > limit ? duration - limit : Duration.zero;
  bool get needsAnyTranscode => needsVideoTranscode || needsAudioTranscode;
  bool get needsAnyFix => needsAnyTranscode || needsRemux || isOverLength;
}

FixPlan buildFixPlan(MediaInfo info, Preset preset) {
  // A 10-bit / non-yuv420p pixel format passes the codec check (still "h264")
  // but is rejected by WhatsApp, so it must force a real transcode.
  final pix = info.pixelFormat;
  final badPixelFormat = pix != null && pix != kTargetPixelFormat;
  return FixPlan(
    needsVideoTranscode: info.videoCodec != kTargetVideoCodec || badPixelFormat,
    needsAudioTranscode:
        info.audioCodec != null && info.audioCodec != kTargetAudioCodec,
    needsRemux: !info.formatName.contains('mp4'),
    isOverLength: info.duration > preset.maxDuration,
    duration: info.duration,
    limit: preset.maxDuration,
  );
}
