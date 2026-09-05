import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';

// How many, stepped rather than typed. A head count is a small number chosen
// with a thumb, and a keyboard covering half the sheet to enter one digit is
// the wrong trade.
class CountPicker extends StatelessWidget {
  const CountPicker({
    required this.value,
    required this.onChanged,
    required this.noun,
    this.least = 1,
    this.most = 16,
    super.key,
  });

  // Absent is not the same as the smallest one asked for: a search with no
  // head count is not a search for a single guest.
  final int? value;

  final ValueChanged<int?> onChanged;
  final String noun;
  final int least;
  final int most;

  @override
  Widget build(BuildContext context) {
    final int? value = this.value;

    return Container(
      height: AppSizes.touchTarget,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadii.medium,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: value == null ? null : () => _step(-1),
            icon: const Icon(Icons.remove),
            tooltip: 'Fewer',
          ),
          Expanded(
            child: Text(
              value == null
                  ? 'Any'
                  : '$value ${value == 1 ? noun : "${noun}s"}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            onPressed: value == most ? null : () => _step(1),
            icon: const Icon(Icons.add),
            tooltip: 'More',
          ),
        ],
      ),
    );
  }

  // Stepping below the smallest count clears the filter rather than stopping
  // at it, so the control that set it is the control that takes it off.
  void _step(int by) {
    final int? value = this.value;
    if (value == null) {
      onChanged(least);

      return;
    }

    final int stepped = value + by;

    onChanged(stepped < least ? null : (stepped > most ? most : stepped));
  }
}

// A price band as its two ends. Neither end is required, and an end left empty
// is one the search does not name at all.
class PriceBand extends StatefulWidget {
  const PriceBand({
    required this.least,
    required this.most,
    required this.onChanged,
    super.key,
  });

  final double? least;
  final double? most;
  final void Function(double? least, double? most) onChanged;

  @override
  State<PriceBand> createState() => _PriceBandState();
}

class _PriceBandState extends State<PriceBand> {
  late final TextEditingController _least = _controllerFor(widget.least);
  late final TextEditingController _most = _controllerFor(widget.most);

  @override
  void dispose() {
    _least.dispose();
    _most.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _field(_least, 'From')),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _field(_most, 'To')),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label) => TextField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      suffixText: AppNumbers.currency,
    ),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: <TextInputFormatter>[InputFormats.amount],
    onChanged: (String _) => _report(),
  );

  void _report() => widget.onChanged(_amount(_least), _amount(_most));

  static double? _amount(TextEditingController controller) =>
      double.tryParse(controller.text);

  static TextEditingController _controllerFor(double? value) =>
      TextEditingController(text: value == null ? '' : AppNumbers.typed(value));
}
