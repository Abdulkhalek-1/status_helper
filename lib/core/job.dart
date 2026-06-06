import 'media_info.dart';
import 'length_resolver.dart';

/// Everything needed to run a conversion and report results.
class ConversionJob {
  final String inputPath;
  final MediaInfo info;
  final List<OutputOp> ops;
  final String outputDir;
  final String baseName; // output filename without suffix or extension

  const ConversionJob({
    required this.inputPath,
    required this.info,
    required this.ops,
    required this.outputDir,
    required this.baseName,
  });
}
