import 'package:flutter_test/flutter_test.dart';
import 'package:status_helper/presets/platform_presets.dart';

void main() {
  test('whatsapp preset has a 90 second limit', () {
    final whatsapp = kPresets.firstWhere((p) => p.id == 'whatsapp');
    expect(whatsapp.displayName, 'WhatsApp');
    expect(whatsapp.maxDuration, const Duration(seconds: 90));
  });

  test('all presets have unique ids and positive limits', () {
    final ids = kPresets.map((p) => p.id).toSet();
    expect(ids.length, kPresets.length);
    for (final p in kPresets) {
      expect(p.maxDuration > Duration.zero, isTrue);
    }
  });
}
