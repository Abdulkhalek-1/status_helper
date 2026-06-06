import 'package:flutter/material.dart';
import '../presets/platform_presets.dart';
import '../core/media_probe.dart';
import '../core/compatibility.dart';
import 'plan_screen.dart';

/// Probes [path], builds the fix plan for [preset], and pushes the PlanScreen
/// onto [navigator]. Shows a SnackBar on [messenger] if the file can't be read.
///
/// Takes the navigator/messenger *states* (not a BuildContext) so it works from
/// both the home picker and the share intake — the latter only has the root
/// navigator's own context, from which `Navigator.of` cannot find the navigator.
Future<void> openPlanForVideo(
  NavigatorState navigator,
  ScaffoldMessengerState messenger,
  String path, {
  Preset preset = kDefaultPreset,
}) async {
  try {
    debugPrint('[share] openPlanForVideo: probing $path');
    final info = await probeMedia(path);
    final plan = buildFixPlan(info, preset);
    debugPrint('[share] openPlanForVideo: probe OK, pushing PlanScreen');
    navigator.push(MaterialPageRoute(
      builder: (_) => PlanScreen(
        inputPath: path,
        info: info,
        plan: plan,
        preset: preset,
      ),
    ));
  } on FormatException catch (e) {
    debugPrint('[share] openPlanForVideo: FormatException: ${e.message}');
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    debugPrint('[share] openPlanForVideo: error: $e');
    messenger.showSnackBar(
      const SnackBar(content: Text('Something went wrong reading that video.')),
    );
  }
}
