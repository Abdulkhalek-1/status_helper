import 'package:flutter/material.dart';
import '../presets/platform_presets.dart';
import '../core/media_probe.dart';
import '../core/compatibility.dart';
import 'plan_screen.dart';

/// Probes [path], builds the fix plan for [preset], and pushes the PlanScreen.
/// Shows a SnackBar on failure. Shared by the home picker and the share intake
/// so both entry points behave identically.
Future<void> openPlanForVideo(
  BuildContext context,
  String path, {
  Preset preset = kDefaultPreset,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final info = await probeMedia(path);
    final plan = buildFixPlan(info, preset);
    navigator.push(MaterialPageRoute(
      builder: (_) => PlanScreen(
        inputPath: path,
        info: info,
        plan: plan,
        preset: preset,
      ),
    ));
  } on FormatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Something went wrong reading that video.')),
    );
  }
}
