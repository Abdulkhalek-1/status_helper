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
    // A video shared while the app is already running.
    _sub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handleShared, onError: (_) {});
    // A video that launched the app from the share sheet (cold start).
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handleShared(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  void _handleShared(List<SharedMediaFile> files) {
    String? videoPath;
    for (final f in files) {
      if (f.type == SharedMediaType.video) {
        videoPath = f.path;
        break;
      }
    }
    if (videoPath == null) return;
    final path = videoPath;
    // Defer until the navigator is mounted, then open the plan directly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navKey.currentContext;
      if (ctx != null) openPlanForVideo(ctx, path);
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
