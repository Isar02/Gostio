import 'package:flutter/material.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({required this.apiBaseUrl, super.key});

  final Uri apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Gostio', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            SelectableText(
              apiBaseUrl.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
