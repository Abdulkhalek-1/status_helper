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
