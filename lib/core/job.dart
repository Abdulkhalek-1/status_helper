import 'media_info.dart';
import 'length_resolver.dart';

/// Everything needed to run a conversion and report results.
class ConversionJob {
  final String inputPath;
  final MediaInfo info;
  final List<OutputOp> ops;
  final String outputDir;
  final String baseName; // output filename without suffix or extension

  /// Force a WhatsApp-safe re-encode of every op even if the streams look
  /// compatible (the "Convert anyway" path).
  final bool forceReencode;

  const ConversionJob({
    required this.inputPath,
    required this.info,
    required this.ops,
    required this.outputDir,
    required this.baseName,
    this.forceReencode = false,
  }) : assert(ops.length > 0);
}
