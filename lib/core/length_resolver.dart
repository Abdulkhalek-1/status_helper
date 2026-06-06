/// The three over-length strategies offered to the user.
enum LengthStrategy { split, trim, speedUp }

/// Above this factor, sped-up video looks comical, so speed-up is disallowed.
const double kMaxSpeedFactor = 1.5;

/// One output the runner must produce. A passthrough/whole-file op leaves
/// startOffset and clipDuration null and speedFactor at 1.0.
class OutputOp {
  final Duration? startOffset; // FFmpeg -ss
  final Duration? clipDuration; // FFmpeg -t
  final double speedFactor; // 1.0 = unchanged
  final String suffix; // appended to the output filename

  const OutputOp({
    this.startOffset,
    this.clipDuration,
    this.speedFactor = 1.0,
    this.suffix = '',
  });

  bool get clipsTime => startOffset != null || clipDuration != null;
  bool get changesSpeed => speedFactor != 1.0;
}

List<OutputOp> passthroughOps() => const [OutputOp()];

List<OutputOp> splitOps(Duration total, Duration limit) {
  final ops = <OutputOp>[];
  var start = Duration.zero;
  var index = 1;
  while (start < total) {
    final remaining = total - start;
    final part = remaining < limit ? remaining : limit;
    ops.add(OutputOp(
      startOffset: start,
      clipDuration: part,
      suffix: '_part$index',
    ));
    start += limit;
    index++;
  }
  return ops;
}

List<OutputOp> trimOps(Duration start, Duration limit) =>
    [OutputOp(startOffset: start, clipDuration: limit)];

bool canSpeedUp(Duration total, Duration limit) =>
    total.inMilliseconds / limit.inMilliseconds <= kMaxSpeedFactor;

List<OutputOp> speedUpOps(Duration total, Duration limit) {
  final factor = total.inMilliseconds / limit.inMilliseconds;
  if (factor > kMaxSpeedFactor) {
    throw ArgumentError('Speed factor $factor exceeds $kMaxSpeedFactor');
  }
  return [OutputOp(speedFactor: factor)];
}
