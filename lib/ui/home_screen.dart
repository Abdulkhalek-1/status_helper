import 'package:flutter/material.dart';
import '../presets/platform_presets.dart';
import '../services/file_service.dart';
import 'open_plan.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fileService = FileService();
  Preset _preset = kDefaultPreset;
  bool _busy = false;

  Future<void> _pickAndAnalyze() async {
    setState(() => _busy = true);
    try {
      final path = await _fileService.pickVideo();
      if (path == null) return;
      if (!mounted) return;
      await openPlanForVideo(context, path, preset: _preset);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('status_helper')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Make any video postable as a status.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            DropdownButtonFormField<Preset>(
              initialValue: _preset,
              decoration: const InputDecoration(
                labelText: 'Target app',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final p in kPresets)
                  DropdownMenuItem(value: p, child: Text(p.displayName)),
              ],
              onChanged: _busy
                  ? null
                  : (p) => setState(() => _preset = p ?? _preset),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _pickAndAnalyze,
              icon: const Icon(Icons.video_library),
              label: Text(_busy ? 'Analyzing…' : 'Pick a video'),
            ),
          ],
        ),
      ),
    );
  }
}
