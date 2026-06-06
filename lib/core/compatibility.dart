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
