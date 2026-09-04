import 'package:flutter/material.dart';

import '../core/config/app_settings.dart';
import 'startup_screen.dart';

class GostioApp extends StatelessWidget {
  const GostioApp({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gostio',
      debugShowCheckedModeBanner: false,
      home: StartupScreen(apiBaseUrl: settings.apiBaseUrl),
    );
  }
}
