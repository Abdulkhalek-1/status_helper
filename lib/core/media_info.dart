import 'dart:convert';

/// Immutable description of a probed media file.
class MediaInfo {
  final String videoCodec;
  final String? audioCodec;
  final Duration duration;
  final int width;
  final int height;
  final String formatName;

  /// Video pixel format, e.g. `yuv420p` (8-bit, WhatsApp-safe) or
  /// `yuv420p10le` (10-bit, which WhatsApp rejects). Null if unknown.
  final String? pixelFormat;

  /// H.264 profile string, e.g. `High`, `Main`, `High 10`. Null if unknown.
  final String? profile;

  const MediaInfo({
    required this.videoCodec,
    required this.audioCodec,
    required this.duration,
    required this.width,
    required this.height,
    required this.formatName,
    this.pixelFormat,
    this.profile,
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
    pixelFormat: video['pix_fmt'] == null ? null : '${video['pix_fmt']}',
    profile: video['profile'] == null ? null : '${video['profile']}',
  );
}
