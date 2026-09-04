import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/writing_notifier.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/confirmation_dialog.dart';

// What a term that already exists can still be told: how many places it takes
// and whether it is open. When it runs is not among them, because the API has
// no endpoint for moving a term a guest has already booked an hour of.
class ExperienceSlotDialog extends StatefulWidget {
  const ExperienceSlotDialog({
    required this.slot,
    required this.save,
    required this.remove,
    required this.countReservations,
    super.key,
  });

  final ExperienceSlot slot;
  final Future<WriteOutcome> Function({
    required int capacity,
    required bool isActive,
  })
  save;
  final Future<WriteOutcome> Function() remove;

  // Cancelled reservations included: a place they freed is still a foreign key
  // that refuses the delete. A count that fails leaves that to the server.
  final Future<int> Function() countReservations;

  @override
  State<ExperienceSlotDialog> createState() => _ExperienceSlotDialogState();
}

class _ExperienceSlotDialogState extends State<ExperienceSlotDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _capacity = TextEditingController();

  late bool _isActive = widget.slot.isActive;
  bool _isSaving = false;
  bool _isCounting = true;
  int? _held;
  ApiException? _failure;

  @override
  void initState() {
    super.initState();
    _capacity.text = '${widget.slot.capacity}';
    unawaited(_count());
  }

  Future<void> _count() async {
    int? held;

    try {
      held = await widget.countReservations();
    } on ApiException {
      held = null;
    }

    if (mounted) {
      setState(() {
        _held = held;
        _isCounting = false;
      });
    }
  }

  @override
  void dispose() {
    _capacity.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ExperienceSlot slot = widget.slot;
    final TextTheme text = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(
        'Term on ${AppDates.dateTime(slot.startTime)}',
        style: text.titleLarge,
      ),
      content: SizedBox(
        width: AppSizes.panel,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(_runs, style: text.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              if (_failure case final ApiException failure
                  when !failure.faultsAField) ...<Widget>[
                AppNotice(failure.message),
                const SizedBox(height: AppSpacing.lg),
              ],
              TextFormField(
                controller: _capacity,
                enabled: !_isSaving,
                inputFormatters: <TextInputFormatter>[InputFormats.whole],
                decoration: InputDecoration(
                  labelText: 'Places',
                  errorText: _failure?.firstMessageFor('capacity'),
                ),
                validator: _refuseCapacity,
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                value: _isActive,
                onChanged: _isSaving || (slot.isBooked && _isActive)
                    ? null
                    : (bool open) => setState(() => _isActive = open),
                contentPadding: EdgeInsets.zero,
                title: Text('Open for booking', style: text.bodyMedium),
                subtitle: Text(_openness, style: text.bodySmall),
              ),
              if (slot.isBooked) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                AppNotice(_booked, tone: Tone.attention),
              ],
            ],
          ),
        ),
      ),
      // The row of actions is an OverflowBar, which takes no Spacer.
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: <Widget>[
        Tooltip(
          message: _deleteMeans,
          child: TextButton(
            onPressed: _canDelete ? _confirmDelete : null,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: Text(_isSaving ? 'Saving' : 'Save term'),
            ),
          ],
        ),
      ],
    );
  }

  String get _runs {
    final ExperienceSlot slot = widget.slot;

    return '${AppDurations.inWords(slot.durationMinutes)} · ends '
        '${AppDates.time(slot.endTime)} · ${slot.bookedCapacity} of '
        '${slot.capacity} ${slot.capacity == 1 ? 'place' : 'places'} booked';
  }

  bool get _canDelete => !_isSaving && !_isCounting && (_held ?? 0) == 0;

  String get _deleteMeans => switch (_held) {
    _ when _isCounting => 'Reading what this term holds.',
    final int held when held > 0 =>
      'This slot has reservations that have to be kept, so it cannot be '
          'deleted.',
    _ => 'Delete this term.',
  };

  String get _openness => _isActive
      ? 'Guests can book a place on this term.'
      : 'Closed: it stays here, and no new booking is made against it.';

  String get _booked =>
      'This term has ${widget.slot.bookedCapacity} of its places booked. '
      'Closing it cancels them, and a cancellation is made through the '
      'reservation.';

  String? _refuseCapacity(String? value) {
    if (Validators.capacity(value) case final String refusal) {
      return refusal;
    }

    final int booked = widget.slot.bookedCapacity;

    return int.parse(value!.trim()) < booked
        ? 'This slot already holds $booked of its places. Its capacity cannot '
              'go below what is booked.'
        : null;
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _failure = null;
      _isSaving = true;
    });

    _settle(
      await widget.save(
        capacity: int.parse(_capacity.text.trim()),
        isActive: _isActive,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Delete this term?',
      message:
          'The term on ${AppDates.dateTime(widget.slot.startTime)} goes, and '
          'the experience keeps every other. This cannot be undone.',
      confirmLabel: 'Delete term',
      isDestructive: true,
    );

    if (!agreed) {
      return;
    }

    setState(() {
      _failure = null;
      _isSaving = true;
    });

    _settle(await widget.remove());
  }

  void _settle(WriteOutcome outcome) {
    if (!mounted) {
      return;
    }

    if (outcome.wasWritten) {
      Navigator.of(context).pop();

      return;
    }

    setState(() {
      _failure = outcome.refusal;
      _isSaving = false;
    });
  }
}
