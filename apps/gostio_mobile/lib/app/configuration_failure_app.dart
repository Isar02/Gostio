import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../core/theme/app_metrics.dart';
import '../core/theme/app_theme.dart';

class ConfigurationFailureApp extends StatelessWidget {
  const ConfigurationFailureApp({required this.reason, super.key});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gostio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Gostio cannot start', style: text.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              SelectableText(
                reason,
                style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
