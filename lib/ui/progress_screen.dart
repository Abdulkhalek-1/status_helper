import 'package:flutter/material.dart';
import '../core/ffmpeg_runner.dart';
import '../core/job.dart';
import 'result_screen.dart';

class ProgressScreen extends StatefulWidget {
  final ConversionJob job;
  const ProgressScreen({super.key, required this.job});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _runner = FfmpegRunner();
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final outputs = await _runner.run(
        widget.job,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      if (outputs.isEmpty) {
        Navigator.of(context).pop(); // cancelled
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(outputPaths: outputs)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _cancel() async {
    await _runner.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Working…')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error == null) ...[
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 16),
              Text('${(_progress * 100).round()}%'),
              const SizedBox(height: 24),
              OutlinedButton(onPressed: _cancel, child: const Text('Cancel')),
            ] else ...[
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
