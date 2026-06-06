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

  /// The initially selected target app; the user can change it on this screen.
  final Preset preset;

  const PlanScreen({
    super.key,
    required this.inputPath,
    required this.info,
    required this.preset,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late Preset _preset;
  LengthStrategy _strategy = LengthStrategy.split;
  Duration _trimStart = Duration.zero;
  bool _convertAnyway = false;

  @override
  void initState() {
    super.initState();
    _preset = widget.preset;
  }

  bool get _canSpeed =>
      canSpeedUp(widget.info.duration, _preset.maxDuration);

  String _formatSubtitle(FixPlan plan) {
    final info = widget.info;
    final pix = info.pixelFormat;
    if (plan.needsVideoTranscode) {
      final parts = <String>[];
      if (info.videoCodec != kTargetVideoCodec) {
        parts.add(info.videoCodec.toUpperCase());
      }
      if (pix != null && pix != kTargetPixelFormat) parts.add(pix);
      final what =
          parts.isEmpty ? info.videoCodec.toUpperCase() : parts.join(', ');
      return '$what → will convert to H.264 (8-bit)';
    }
    return 'H.264${pix != null ? ', $pix' : ''} — compatible';
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  List<OutputOp> _buildOps() {
    final limit = _preset.maxDuration;
    if (widget.info.duration <= limit) return passthroughOps();
    switch (_strategy) {
      case LengthStrategy.split:
        return splitOps(widget.info.duration, limit);
      case LengthStrategy.trim:
        return trimOps(_trimStart, limit);
      case LengthStrategy.speedUp:
        return speedUpOps(widget.info.duration, limit);
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
      forceReencode: _convertAnyway,
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProgressScreen(job: job)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = buildFixPlan(widget.info, _preset);
    final limit = _preset.maxDuration;
    final maxTrimStart = widget.info.duration > limit
        ? (widget.info.duration - limit)
        : Duration.zero;

    return Scaffold(
      appBar: AppBar(title: const Text('Prepare video')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Preset>(
            initialValue: _preset,
            decoration: const InputDecoration(
              labelText: 'Target app',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final pr in kPresets)
                DropdownMenuItem(value: pr, child: Text(pr.displayName)),
            ],
            onChanged: (pr) => setState(() {
              if (pr == null) return;
              _preset = pr;
              // Length limit changed; reset the over-length choices.
              _strategy = LengthStrategy.split;
              _trimStart = Duration.zero;
            }),
          ),
          const SizedBox(height: 8),
          _findingTile(
            icon: plan.needsVideoTranscode ? Icons.build : Icons.check_circle,
            title: 'Video',
            subtitle: _formatSubtitle(plan),
          ),
          if (widget.info.audioCodec != null)
            _findingTile(
              icon: plan.needsAudioTranscode ? Icons.build : Icons.check_circle,
              title: 'Audio',
              subtitle: plan.needsAudioTranscode
                  ? '${widget.info.audioCodec!.toUpperCase()} → will convert to AAC'
                  : 'AAC — compatible',
            ),
          if (plan.needsRemux)
            _findingTile(
              icon: Icons.build,
              title: 'Container',
              subtitle: '${widget.info.formatName} → will repackage as MP4',
            ),
          _findingTile(
            icon: plan.isOverLength ? Icons.timer : Icons.check_circle,
            title: 'Length',
            subtitle: plan.isOverLength
                ? '${_fmt(widget.info.duration)}, over the ${limit.inSeconds}s limit'
                : '${_fmt(widget.info.duration)}, within the limit',
          ),
          if (plan.isOverLength) ...[
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
          const Divider(height: 32),
          SwitchListTile(
            value: _convertAnyway,
            onChanged: (v) => setState(() => _convertAnyway = v),
            title: const Text('Convert anyway'),
            subtitle: const Text(
                'Force a safe re-encode even if it looks compatible. '
                'Try this if the target app still rejects the video.'),
          ),
          _detailsPanel(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.auto_fix_high),
            label: Text((plan.needsAnyFix || _convertAnyway)
                ? 'Fix it'
                : 'Prepare for sharing'),
          ),
        ],
      ),
    );
  }

  Widget _detailsPanel() {
    final info = widget.info;
    final lines = <String>[
      'Container: ${info.formatName.isEmpty ? 'unknown' : info.formatName}',
      'Video: ${info.videoCodec}'
          '${info.profile != null ? ' (${info.profile})' : ''}',
      'Pixel format: ${info.pixelFormat ?? 'unknown'}',
      'Resolution: ${info.width}×${info.height}',
      'Audio: ${info.audioCodec ?? 'none'}',
      'Duration: ${_fmt(info.duration)}',
    ];
    return ExpansionTile(
      title: const Text('Video details'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        for (final l in lines)
          Align(alignment: Alignment.centerLeft, child: Text(l)),
      ],
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
