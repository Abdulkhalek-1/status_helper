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

const _with10BitProfile = '''
{
  "streams": [
    {"codec_type": "video", "codec_name": "h264", "width": 1080, "height": 1920,
     "pix_fmt": "yuv420p10le", "profile": "High 10"}
  ],
  "format": {"duration": "12.0", "format_name": "mov,mp4"}
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

  test('parses pixel format and profile', () {
    final info = parseProbeJson(_with10BitProfile);
    expect(info.pixelFormat, 'yuv420p10le');
    expect(info.profile, 'High 10');
  });

  test('pixelFormat and profile are null when absent', () {
    final info = parseProbeJson(_videoOnly);
    expect(info.pixelFormat, isNull);
    expect(info.profile, isNull);
  });

  test('throws FormatException when there is no video stream', () {
    const noVideo = '{"streams": [], "format": {"duration": "1.0"}}';
    expect(() => parseProbeJson(noVideo), throwsA(isA<FormatException>()));
  });
}
