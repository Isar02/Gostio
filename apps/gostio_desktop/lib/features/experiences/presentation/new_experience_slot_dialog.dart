import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/writing_notifier.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/time_field.dart';

// A term is created from when it starts and how many places it takes. How long
// it runs is the experience's own duration, which is why it is stated here
// rather than asked for.
class NewExperienceSlotDialog extends StatefulWidget {
  const NewExperienceSlotDialog({
    required this.durationMinutes,
    required this.add,
    super.key,
  });

  final int durationMinutes;
  final Future<WriteOutcome> Function({
    required DateTime startTime,
    required int capacity,
  })
  add;

  @override
  State<NewExperienceSlotDialog> createState() =>
      _NewExperienceSlotDialogState();
}

class _NewExperienceSlotDialogState extends State<NewExperienceSlotDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _capacity = TextEditingController();

  DateTime? _day;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  bool _isSaving = false;
  ApiException? _failure;
  String? _dayFault;

  @override
  void dispose() {
    _capacity.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text('New term', style: text.titleLarge),
      content: SizedBox(
        width: AppSizes.panel,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_failure case final ApiException failure
                  when !failure.faultsAField) ...<Widget>[
                AppNotice(failure.message),
                const SizedBox(height: AppSpacing.lg),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: DateField(
                      label: 'Day',
                      hint: 'Choose a day',
                      value: _day,
                      isClearable: false,
                      firstDate: CalendarDays.today(),
                      errorText:
                          _dayFault ?? _failure?.firstMessageFor('startTime'),
                      onChanged: (DateTime? day) => setState(() {
                        _day = day;
                        _dayFault = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TimeField(
                      label: 'Starts at',
                      value: _time,
                      onChanged: (TimeOfDay time) => setState(() {
                        _time = time;
                        _dayFault = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _capacity,
                enabled: !_isSaving,
                inputFormatters: <TextInputFormatter>[InputFormats.whole],
                decoration: InputDecoration(
                  labelText: 'Places',
                  errorText: _failure?.firstMessageFor('capacity'),
                ),
                validator: Validators.capacity,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(_runs, style: text.bodySmall),
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
          child: Text(_isSaving ? 'Adding' : 'Add term'),
        ),
      ],
    );
  }

  String get _runs {
    final String duration = AppDurations.inWords(widget.durationMinutes);

    if (_startTime case final DateTime start) {
      final DateTime end = start.add(Duration(minutes: widget.durationMinutes));

      return 'It runs for $duration, ending at ${AppDates.time(end)}.';
    }

    return 'It runs for $duration, the duration this experience is set to.';
  }

  DateTime? get _startTime {
    if (_day case final DateTime day) {
      return DateTime(day.year, day.month, day.day, _time.hour, _time.minute);
    }

    return null;
  }

  // The server refuses a term that has already begun, so the same refusal is
  // made here in its own words rather than sent to be answered with a 400.
  Future<void> _submit() async {
    final bool written = _form.currentState?.validate() ?? false;
    final DateTime? start = _startTime;

    setState(() {
      _dayFault = switch (start) {
        null => 'Choose when the term starts.',
        _ when !start.isAfter(DateTime.now()) =>
          'A slot starts at a time still to come.',
        _ => null,
      };
    });

    if (!written || _dayFault != null || start == null) {
      return;
    }

    setState(() {
      _failure = null;
      _isSaving = true;
    });

    final WriteOutcome outcome = await widget.add(
      startTime: start,
      capacity: int.parse(_capacity.text.trim()),
    );

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
