import 'package:flutter_test/flutter_test.dart';
import 'package:status_helper/core/media_info.dart';
import 'package:status_helper/core/length_resolver.dart';
import 'package:status_helper/core/ffmpeg_command_builder.dart';

MediaInfo _info({
  String video = 'h264',
  String? audio = 'aac',
  String? pixelFormat = 'yuv420p',
}) =>
    MediaInfo(
      videoCodec: video,
      audioCodec: audio,
      duration: const Duration(seconds: 30),
      width: 720,
      height: 1280,
      formatName: 'mov,mp4',
      pixelFormat: pixelFormat,
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

  test('10-bit h264 re-encodes video instead of copying', () {
    final args = buildFfmpegArgs(_info(pixelFormat: 'yuv420p10le'),
        const OutputOp(), '/in.mp4', '/out.mp4');
    // Video stream is libx264 (not copy); -c:v is immediately followed by it.
    expect(args[args.indexOf('-c:v') + 1], 'libx264');
    expect(args, containsAllInOrder(['-pix_fmt', 'yuv420p']));
  });

  test('re-encode pins a WhatsApp-safe baseline profile/level', () {
    final args = buildFfmpegArgs(
        _info(video: 'hevc'), const OutputOp(), '/in.mkv', '/out.mp4');
    expect(args, containsAllInOrder(['-profile:v', 'high']));
    expect(args, containsAllInOrder(['-level', '4.0']));
  });

  test('forceReencode re-encodes both streams even when compatible', () {
    final args = buildFfmpegArgs(
        _info(), const OutputOp(), '/in.mp4', '/out.mp4',
        forceReencode: true);
    expect(args, containsAllInOrder(['-c:v', 'libx264']));
    expect(args, containsAllInOrder(['-c:a', 'aac']));
    expect(args, isNot(contains('copy')));
  });
}
