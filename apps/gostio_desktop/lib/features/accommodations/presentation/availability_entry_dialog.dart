import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_notice.dart';
import '../data/availability_draft.dart';
import 'availability_words.dart';

// The days are settled before the dialog opens — they are the span chosen on
// the calendar — so what is asked here is only what those days become.
class AvailabilityEntryDialog extends StatefulWidget {
  const AvailabilityEntryDialog({
    required this.from,
    required this.to,
    required this.nights,
    required this.bookedNights,
    required this.nightlyPrice,
    required this.add,
    super.key,
  });

  final DateTime from;
  final DateTime to;
  final int nights;
  final int bookedNights;
  final double nightlyPrice;
  final Future<ApiException?> Function(AvailabilityDraft draft) add;

  @override
  State<AvailabilityEntryDialog> createState() =>
      _AvailabilityEntryDialogState();
}

class _AvailabilityEntryDialogState extends State<AvailabilityEntryDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _price = TextEditingController();

  bool _isOpen = false;
  bool _isSaving = false;
  ApiException? _failure;

  @override
  void initState() {
    super.initState();
    _price.text = AppNumbers.typed(widget.nightlyPrice);
  }

  @override
  void dispose() {
    _price.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text('New calendar entry', style: text.titleLarge),
      content: SizedBox(
        width: AppSizes.panel,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(_span, style: text.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              if (_failure?.message case final String message) ...<Widget>[
                AppNotice(message),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppDropdown<bool>(
                label: 'These nights are',
                value: _isOpen,
                values: const <bool>[false, true],
                labels: (bool isOpen) =>
                    isOpen ? 'Open, at a price of their own' : 'Blocked',
                errorText: _failure?.firstMessageFor('isAvailable'),
                onChanged: (bool isOpen) => setState(() => _isOpen = isOpen),
              ),
              if (_isOpen) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _price,
                  enabled: !_isSaving,
                  inputFormatters: <TextInputFormatter>[InputFormats.amount],
                  decoration: InputDecoration(
                    labelText: 'Nightly price',
                    suffixText: AppNumbers.currency,
                    errorText: _failure?.firstMessageFor(
                      AvailabilityDraft.priceField,
                    ),
                  ),
                  validator: Validators.price,
                ),
              ],
              if (widget.bookedNights > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                AppNotice(_booked, tone: Tone.attention),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: Text(_isSaving ? 'Adding' : 'Add entry'),
        ),
      ],
    );
  }

  String get _span =>
      '${AvailabilityWords.nights(widget.nights)} · '
      '${AvailabilityWords.span(widget.from, widget.to)}';

  // An entry says what the calendar offers from now on, and a booking already
  // made was paid at the price it was made at and keeps its place either way.
  String get _booked {
    final int booked = widget.bookedNights;

    return '$booked of these nights ${booked == 1 ? 'is' : 'are'} booked. '
        'This entry does not move or cancel a booking that already stands.';
  }

  // The dialog stays open when the server refuses, because the fields it is
  // complaining about are the ones on it.
  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _failure = null;
      _isSaving = true;
    });

    final ApiException? refused = await widget.add(
      _isOpen
          ? AvailabilityDraft.open(
              startDate: widget.from,
              endDate: widget.to,
              price: double.parse(_price.text.trim()),
            )
          : AvailabilityDraft.blocked(
              startDate: widget.from,
              endDate: widget.to,
            ),
    );

    if (!mounted) {
      return;
    }

    if (refused == null) {
      Navigator.of(context).pop();

      return;
    }

    setState(() {
      _failure = refused;
      _isSaving = false;
    });
  }
}
