import 'package:flutter_test/flutter_test.dart';
import 'package:status_helper/core/length_resolver.dart';

void main() {
  const limit = Duration(seconds: 90);

  test('passthrough produces one default op', () {
    final ops = passthroughOps();
    expect(ops, hasLength(1));
    expect(ops.single.startOffset, isNull);
    expect(ops.single.clipDuration, isNull);
    expect(ops.single.speedFactor, 1.0);
  });

  test('split of 200s into 90s limit yields 3 parts', () {
    final ops = splitOps(const Duration(seconds: 200), limit);
    expect(ops, hasLength(3));
    expect(ops[0].startOffset, Duration.zero);
    expect(ops[0].clipDuration, limit);
    expect(ops[1].startOffset, limit);
    expect(ops[2].startOffset, const Duration(seconds: 180));
    expect(ops[2].clipDuration, const Duration(seconds: 20));
    expect(ops.map((o) => o.suffix), ['_part1', '_part2', '_part3']);
  });

  test('trim yields one clip at the chosen start, capped at limit', () {
    final ops = trimOps(const Duration(seconds: 30), limit);
    expect(ops, hasLength(1));
    expect(ops.single.startOffset, const Duration(seconds: 30));
    expect(ops.single.clipDuration, limit);
  });

  test('speed-up is allowed when factor <= 1.5', () {
    expect(canSpeedUp(const Duration(seconds: 120), limit), isTrue); // 1.33x
    final ops = speedUpOps(const Duration(seconds: 120), limit);
    expect(ops.single.speedFactor, closeTo(120 / 90, 0.0001));
  });

  test('speed-up is disallowed when factor > 1.5', () {
    expect(canSpeedUp(const Duration(seconds: 200), limit), isFalse); // 2.22x
    expect(() => speedUpOps(const Duration(seconds: 200), limit),
        throwsA(isA<ArgumentError>()));
  });
}
