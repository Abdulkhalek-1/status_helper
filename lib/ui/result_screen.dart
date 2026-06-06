import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../services/file_service.dart';
import '../services/share_service.dart';

class ResultScreen extends StatefulWidget {
  final List<String> outputPaths;
  final String? notice;
  const ResultScreen({super.key, required this.outputPaths, this.notice});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _fileService = FileService();
  final _shareService = ShareService();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _autoSave();
  }

  Future<void> _autoSave() async {
    try {
      if (!await _fileService.hasGalleryAccess()) {
        await _fileService.requestGalleryAccess();
      }
      for (final path in widget.outputPaths) {
        await _fileService.saveToGallery(path);
      }
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      _toast('Saved to app storage (gallery permission denied). You can still share.');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.outputPaths.length > 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Done')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.notice != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                title: Text(
                  widget.notice!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ListTile(
            leading: Icon(_saved ? Icons.check_circle : Icons.hourglass_bottom),
            title: Text(_saved ? 'Saved to gallery' : 'Saving to gallery…'),
            subtitle: Text(multi
                ? '${widget.outputPaths.length} parts ready — post them in order'
                : 'Your video is ready'),
          ),
          const Divider(),
          for (final path in widget.outputPaths)
            ListTile(
              leading: const Icon(Icons.movie),
              title: Text(p.basename(path)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _shareService.shareFiles(widget.outputPaths),
            icon: const Icon(Icons.share),
            label: Text(multi ? 'Share all parts' : 'Share'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Fix another video'),
          ),
        ],
      ),
    );
  }
}
