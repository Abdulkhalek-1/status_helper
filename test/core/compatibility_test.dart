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
