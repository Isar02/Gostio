import 'package:flutter/material.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({required this.apiBaseUrl, super.key});

  final Uri apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Gostio', style: text.displaySmall),
              const SizedBox(height: 8),
              SelectableText(apiBaseUrl.toString(), style: text.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
