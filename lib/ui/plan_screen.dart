import 'package:flutter/material.dart';
import '../core/media_info.dart';
import '../core/compatibility.dart';
import '../core/length_resolver.dart';
import '../core/job.dart';
import '../presets/platform_presets.dart';
import '../services/file_service.dart';
import 'progress_screen.dart';

class PlanScreen extends StatefulWidget {
  final String inputPath;
  final MediaInfo info;
  final FixPlan plan;
  final Preset preset;

  const PlanScreen({
    super.key,
    required this.inputPath,
    required this.info,
    required this.plan,
    required this.preset,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  LengthStrategy _strategy = LengthStrategy.split;
  Duration _trimStart = Duration.zero;

  bool get _canSpeed =>
      canSpeedUp(widget.info.duration, widget.preset.maxDuration);

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  List<OutputOp> _buildOps() {
    if (!widget.plan.isOverLength) return passthroughOps();
    switch (_strategy) {
      case LengthStrategy.split:
        return splitOps(widget.info.duration, widget.preset.maxDuration);
      case LengthStrategy.trim:
        return trimOps(_trimStart, widget.preset.maxDuration);
      case LengthStrategy.speedUp:
        return speedUpOps(widget.info.duration, widget.preset.maxDuration);
    }
  }

  Future<void> _start() async {
    final dir = await FileService().workingDir();
    final job = ConversionJob(
      inputPath: widget.inputPath,
      info: widget.info,
      ops: _buildOps(),
      outputDir: dir,
      baseName: 'status_${DateTime.now().millisecondsSinceEpoch}',
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProgressScreen(job: job)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final limit = widget.preset.maxDuration;
    final maxTrimStart = widget.info.duration > limit
        ? (widget.info.duration - limit)
        : Duration.zero;

    return Scaffold(
      appBar: AppBar(title: Text('Fix for ${widget.preset.displayName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _findingTile(
            icon: p.needsVideoTranscode ? Icons.build : Icons.check_circle,
            title: 'Format',
            subtitle: p.needsVideoTranscode
                ? '${widget.info.videoCodec.toUpperCase()} → will convert to H.264'
                : 'Already compatible',
          ),
          _findingTile(
            icon: p.isOverLength ? Icons.timer : Icons.check_circle,
            title: 'Length',
            subtitle: p.isOverLength
                ? '${_fmt(widget.info.duration)}, over the ${limit.inSeconds}s limit'
                : '${_fmt(widget.info.duration)}, within the limit',
          ),
          if (p.isOverLength) ...[
            const Divider(height: 32),
            Text('How should we shorten it?',
                style: Theme.of(context).textTheme.titleMedium),
            RadioListTile<String>(
              value: 'split',
              groupValue: _strategy.name,
              title: const Text('Split into parts'),
              subtitle: Text(
                  '${splitOps(widget.info.duration, limit).length} parts of ≤${limit.inSeconds}s'),
              onChanged: (_) =>
                  setState(() => _strategy = LengthStrategy.split),
            ),
            RadioListTile<String>(
              value: 'trim',
              groupValue: _strategy.name,
              title: const Text('Trim to a clip'),
              subtitle: Text(
                  'Keep ${limit.inSeconds}s starting at ${_fmt(_trimStart)}'),
              onChanged: (_) =>
                  setState(() => _strategy = LengthStrategy.trim),
            ),
            if (_strategy == LengthStrategy.trim && maxTrimStart > Duration.zero)
              Slider(
                value: _trimStart.inSeconds.toDouble(),
                max: maxTrimStart.inSeconds.toDouble(),
                divisions: maxTrimStart.inSeconds,
                label: _fmt(_trimStart),
                onChanged: (v) =>
                    setState(() => _trimStart = Duration(seconds: v.round())),
              ),
            RadioListTile<String>(
              value: 'speedUp',
              groupValue: _strategy.name,
              title: const Text('Speed up to fit'),
              subtitle: Text(_canSpeed
                  ? 'Slightly faster so it all fits'
                  : 'Too long to speed up watchably'),
              onChanged: _canSpeed
                  ? (_) => setState(() => _strategy = LengthStrategy.speedUp)
                  : null,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.auto_fix_high),
            label: Text(p.needsAnyFix ? 'Fix it' : 'Prepare for sharing'),
          ),
        ],
      ),
    );
  }

  Widget _findingTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      );
}
