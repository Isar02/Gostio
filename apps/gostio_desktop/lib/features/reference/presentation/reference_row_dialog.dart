import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/paging/writing_notifier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../data/lookup_item.dart';
import '../data/reference_row.dart';
import 'reference_layout.dart';

class ReferenceRowDialog extends StatefulWidget {
  const ReferenceRowDialog({
    required this.noun,
    required this.layout,
    required this.save,
    this.remove,
    this.row,
    this.choices = const <LookupItem>[],
    super.key,
  }) : assert(row == null || remove != null);

  final String noun;
  final ReferenceLayout layout;
  final Future<WriteOutcome> Function(JsonMap body) save;
  final Future<WriteOutcome> Function()? remove;

  final ReferenceRow? row;

  final List<LookupItem> choices;

  @override
  State<ReferenceRowDialog> createState() => _ReferenceRowDialogState();
}

class _ReferenceRowDialogState extends State<ReferenceRowDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _written =
      <String, TextEditingController>{};
  final Map<String, int?> _chosen = <String, int?>{};
  final Map<String, String?> _faults = <String, String?>{};

  bool _isSaving = false;
  ApiException? _failure;

  @override
  void initState() {
    super.initState();

    final ReferenceRow? row = widget.row;

    for (final ReferenceField field in widget.layout.form) {
      if (field.kind == ReferenceFieldKind.choice) {
        _chosen[field.key] =
            row?.number(field.key) ??
            (widget.choices.length == 1 ? widget.choices.single.id : null);
      } else {
        _written[field.key] = TextEditingController(
          text: row?.text(field.key) ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _written.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? kept = _keptReason;

    return AlertDialog(
      title: Text(_title, style: Theme.of(context).textTheme.titleLarge),
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
              for (final ReferenceField field
                  in widget.layout.form) ...<Widget>[
                _field(field),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ),
      // The row of actions is an OverflowBar, which takes no Spacer.
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: <Widget>[
        if (widget.row == null)
          const SizedBox.shrink()
        else
          Tooltip(
            message: kept ?? 'Delete this ${widget.noun}.',
            child: TextButton(
              onPressed: kept == null && !_isSaving ? _confirmDelete : null,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: Text(_isReadOnly ? 'Close' : 'Cancel'),
            ),
            if (!_isReadOnly) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: Text(_isSaving ? 'Saving' : _saveLabel),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String get _title => widget.row?.name ?? 'New ${widget.noun}';

  String get _saveLabel =>
      widget.row == null ? 'Add ${widget.noun}' : 'Save ${widget.noun}';

  String? get _keptReason => switch (widget.row) {
    final ReferenceRow row => widget.layout.kept?.call(row),
    null => null,
  };

  bool get _isReadOnly =>
      widget.row != null &&
      widget.layout.form.every(
        (ReferenceField field) => _frozenReason(field.key) != null,
      );

  String? _frozenReason(String key) => switch (widget.row) {
    final ReferenceRow row => widget.layout.frozen?.call(row, key),
    null => null,
  };

  Widget _field(ReferenceField field) {
    final String? frozen = _frozenReason(field.key);

    return field.kind == ReferenceFieldKind.choice
        ? _choice(field, frozen)
        : _line(field, frozen);
  }

  Widget _line(ReferenceField field, String? frozen) {
    return TextFormField(
      controller: _written[field.key],
      enabled: !_isSaving && frozen == null,
      maxLines: field.kind == ReferenceFieldKind.paragraph ? _paragraph : 1,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: frozen,
        helperMaxLines: _helperLines,
        errorText: _failure?.firstMessageFor(field.key),
      ),
      validator: field.validator,
    );
  }

  Widget _choice(ReferenceField field, String? frozen) {
    final Widget control = AppOptionalDropdown<LookupItem>(
      label: field.label,
      anyLabel: field.hint ?? 'Choose one',
      errorText: _faults[field.key] ?? _failure?.firstMessageFor(field.key),
      value: _chosenItem(field.key),
      values: widget.choices,
      labels: (LookupItem option) => option.name,
      onChanged: (LookupItem? option) => setState(() {
        _chosen[field.key] = option?.id;
        _faults[field.key] = null;
      }),
    );

    if (frozen == null) {
      return control;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AbsorbPointer(
          child: Opacity(opacity: _dimmed, child: control),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(frozen, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  LookupItem? _chosenItem(String key) {
    for (final LookupItem option in widget.choices) {
      if (option.id == _chosen[key]) {
        return option;
      }
    }

    return null;
  }

  JsonMap get _body => <String, dynamic>{
    for (final ReferenceField field in widget.layout.form)
      field.key: field.kind == ReferenceFieldKind.choice
          ? _chosen[field.key]
          : _written[field.key]!.text.trim(),
  };

  Future<void> _submit() async {
    final bool written = _form.currentState?.validate() ?? false;

    setState(() {
      for (final ReferenceField field in widget.layout.form) {
        if (field.kind == ReferenceFieldKind.choice) {
          _faults[field.key] = _chosen[field.key] == null
              ? field.missing
              : null;
        }
      }
    });

    if (!written || _faults.values.any((String? fault) => fault != null)) {
      return;
    }

    setState(() {
      _failure = null;
      _isSaving = true;
    });

    _settle(await widget.save(_body), _wrote);
  }

  Future<void> _confirmDelete() async {
    final Future<WriteOutcome> Function()? remove = widget.remove;
    if (remove == null) {
      return;
    }

    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Delete this ${widget.noun}?',
      message:
          '$_title goes from the table. One that another record points at is '
          'kept by the server, and this cannot be undone.',
      confirmLabel: 'Delete ${widget.noun}',
      isDestructive: true,
    );

    if (!agreed) {
      return;
    }

    setState(() {
      _failure = null;
      _isSaving = true;
    });

    _settle(await remove(), '$_title was deleted.');
  }

  void _settle(WriteOutcome outcome, String said) {
    if (!mounted) {
      return;
    }

    if (outcome.wasWritten) {
      final String message = outcome.viewSettled
          ? said
          : '$said The table could not be read again.';
      Navigator.of(context).pop(message);

      return;
    }

    setState(() {
      _failure = outcome.refusal;
      _isSaving = false;
    });
  }

  String get _wrote {
    final String name = _written[ReferenceKeys.name]!.text.trim();

    return widget.row == null ? '$name was created.' : '$name was saved.';
  }

  static const int _paragraph = 3;
  static const int _helperLines = 3;
  static const double _dimmed = 0.5;
}
