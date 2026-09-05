import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';

// What a booking is made of and what it adds up to. Every figure on it came
// from the server; the words in front of them say which part of the booking
// each one is.
class PriceTable extends StatelessWidget {
  const PriceTable({required this.lines, required this.total, super.key});

  final List<(String, double)> lines;
  final double total;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        for (final (String label, double amount) in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _Line(
              label: label,
              amount: amount,
              style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
          ),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        _Line(label: 'Total', amount: total, style: text.titleMedium),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.amount, this.style});

  final String label;
  final double amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: AppSpacing.md),
        Text(AppNumbers.money(amount), style: style),
      ],
    );
  }
}
