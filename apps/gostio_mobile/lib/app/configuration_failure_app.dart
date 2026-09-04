import 'package:flutter/material.dart';

class ConfigurationFailureApp extends StatelessWidget {
  const ConfigurationFailureApp({required this.reason, super.key});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gostio',
      debugShowCheckedModeBanner: false,
      home: _ConfigurationFailureScreen(reason: reason),
    );
  }
}

class _ConfigurationFailureScreen extends StatelessWidget {
  const _ConfigurationFailureScreen({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Gostio cannot start', style: text.headlineSmall),
              const SizedBox(height: 12),
              SelectableText(reason, style: text.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
