import 'package:flutter/material.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const StatusHelperApp());
}

class StatusHelperApp extends StatelessWidget {
  const StatusHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'status_helper',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
