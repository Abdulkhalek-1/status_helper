import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path/path.dart' as p;
import 'job.dart';
import 'length_resolver.dart';
import 'ffmpeg_command_builder.dart';

/// Thrown when an op fails mid-run. [producedOutputs] holds the paths of any
/// parts that completed successfully before the failure (kept on disk per spec).
class ConversionException implements Exception {
  final String message;
  final List<String> producedOutputs;
  ConversionException(this.message, this.producedOutputs);
  @override
  String toString() => message;
}

/// Runs a [ConversionJob], writing one MP4 per OutputOp.
class FfmpegRunner {
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
    final safeTotal = totalMs > 0 ? totalMs : 1;

    for (final op in job.ops) {
      if (_cancelled) break;
      final outPath = p.join(job.outputDir, '${job.baseName}${op.suffix}.mp4');
      final args = buildFfmpegArgs(job.info, op, job.inputPath, outPath);
      final opMs = _opDurationMs(job, op);

      final completer = Completer<bool>();
      await FFmpegKit.executeWithArgumentsAsync(
        args,
        (FFmpegSession session) async {
          final rc = await session.getReturnCode();
          completer.complete(ReturnCode.isSuccess(rc));
        },
        null,
        (Statistics s) {
          if (opMs > 0) {
            final frac = (s.getTime() / opMs).clamp(0.0, 1.0);
            onProgress?.call(
              ((completedMs + frac * opMs) / safeTotal).clamp(0.0, 1.0),
            );
          }
        },
      );

      final ok = await completer.future;
      if (_cancelled) {
        _deleteQuietly(outPath);
        break;
      }
      if (!ok) {
        throw ConversionException(
          'Conversion failed for ${op.suffix.isEmpty ? "video" : op.suffix}',
          List.unmodifiable(outputs),
        );
      }
      outputs.add(outPath);
      completedMs += opMs;
      onProgress?.call((completedMs / safeTotal).clamp(0.0, 1.0));
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
