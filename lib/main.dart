import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'ui/home_screen.dart';
import 'ui/open_plan.dart';

void main() {
  runApp(const StatusHelperApp());
}

class StatusHelperApp extends StatefulWidget {
  const StatusHelperApp({super.key});

  @override
  State<StatusHelperApp> createState() => _StatusHelperAppState();
}

class _StatusHelperAppState extends State<StatusHelperApp> {
  final _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<List<SharedMediaFile>>? _sub;

  @override
  void initState() {
    super.initState();
    debugPrint('[share] initState: registering listeners');
    // A video shared while the app is already running.
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        debugPrint('[share] stream emitted ${files.length} file(s)');
        _handleShared(files);
      },
      onError: (e) => debugPrint('[share] stream error: $e'),
    );
    // A video that launched the app from the share sheet (cold start).
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      debugPrint('[share] getInitialMedia returned ${files.length} file(s)');
      _handleShared(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  static const _videoExtensions = [
    '.mp4', '.mov', '.mkv', '.webm', '.avi', '.3gp', '.m4v', '.ts',
  ];

  /// Picks a shared video, tolerating apps that mis-type it as a generic file.
  String? _firstVideoPath(List<SharedMediaFile> files) {
    for (final f in files) {
      if (f.type == SharedMediaType.video) return f.path;
    }
    for (final f in files) {
      final mime = f.mimeType ?? '';
      final lower = f.path.toLowerCase();
      if (mime.startsWith('video/') ||
          _videoExtensions.any(lower.endsWith)) {
        return f.path;
      }
    }
    return null;
  }

  void _handleShared(List<SharedMediaFile> files) {
    for (final f in files) {
      debugPrint('[share]   file type=${f.type} mime=${f.mimeType} path=${f.path}');
    }
    final path = _firstVideoPath(files);
    debugPrint('[share] chosen video path: $path');
    if (path == null) return;
    // Defer until the navigator is mounted, then open the plan directly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navKey.currentState;
      final ctx = _navKey.currentContext;
      debugPrint('[share] postFrame: navigator=${navigator != null} ctx=${ctx != null}');
      if (navigator != null && ctx != null) {
        openPlanForVideo(navigator, ScaffoldMessenger.of(ctx), path);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: 'status_helper',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
