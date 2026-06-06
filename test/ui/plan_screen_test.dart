import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:status_helper/core/media_info.dart';
import 'package:status_helper/presets/platform_presets.dart';
import 'package:status_helper/ui/plan_screen.dart';

MediaInfo _info(int seconds) => MediaInfo(
      videoCodec: 'hevc',
      audioCodec: 'aac',
      duration: Duration(seconds: seconds),
      width: 720,
      height: 1280,
      formatName: 'mov,mp4',
    );

Widget _wrap(int seconds) {
  final info = _info(seconds);
  return MaterialApp(
    home: PlanScreen(
      inputPath: '/in.mp4',
      info: info,
      preset: kDefaultPreset,
    ),
  );
}

void main() {
  testWidgets('over by a lot disables speed-up', (tester) async {
    await tester.pumpWidget(_wrap(200)); // 2.22x
    final speedTile = tester.widget<RadioListTile<String>>(
      find.widgetWithText(RadioListTile<String>, 'Speed up to fit'),
    );
    expect(speedTile.onChanged, isNull); // disabled
  });

  testWidgets('modest overage enables speed-up', (tester) async {
    await tester.pumpWidget(_wrap(120)); // 1.33x
    final speedTile = tester.widget<RadioListTile<String>>(
      find.widgetWithText(RadioListTile<String>, 'Speed up to fit'),
    );
    expect(speedTile.onChanged, isNotNull); // enabled
  });
}
