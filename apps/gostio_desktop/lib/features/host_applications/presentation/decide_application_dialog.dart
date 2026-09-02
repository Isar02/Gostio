import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_notice.dart';
import '../data/host_application.dart';

// The two answers a request takes. A rejection has to say why and an approval
// does not, which is the server's rule and the only thing that differs.
enum ApplicationDecision {
  approve('Approve', 'Approving'),
  reject('Turn down', 'Turning down');

  const ApplicationDecision(this.verb, this.working);

  final String verb;
  final String working;

  bool get demandsAReason => this == reject;
}

// Answering a request cannot be undone, so the dialog is the confirmation:
// what it does to the account, and the reason that goes out with it.
class DecideApplicationDialog extends StatefulWidget {
  const DecideApplicationDialog({
    required this.application,
    required this.decision,
    required this.decide,
    super.key,
  });

  final HostApplication application;
  final ApplicationDecision decision;

  // An approval with nothing typed hands back an empty string, which the
  // screen reads as the reason it does not have.
  final Future<ApiException?> Function(String reason) decide;

  @override
  State<DecideApplicationDialog> createState() =>
      _DecideApplicationDialogState();
}

class _DecideApplicationDialogState extends State<DecideApplicationDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _reason = TextEditingController();

  bool _isSaving = false;
  ApiException? _failure;

  @override
  void dispose() {
    _reason.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A refusal is said in this dialog, so it cannot be dismissed out from
    // under a write that is still running.
    return PopScope(canPop: !_isSaving, child: _dialog(context));
  }

  Widget _dialog(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ApplicationDecision decision = widget.decision;

    return AlertDialog(
      title: Text('${decision.verb} this application?', style: text.titleLarge),
      content: SizedBox(
        width: AppSizes.panel,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _whatHappens,
                style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_failure case final ApiException failure
                  when !failure.faultsAField) ...<Widget>[
                AppNotice(failure.message),
                const SizedBox(height: AppSpacing.lg),
              ],
              TextFormField(
                controller: _reason,
                enabled: !_isSaving,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  alignLabelWithHint: true,
                  helperText: decision.demandsAReason
                      ? 'The applicant is told why.'
                      : 'Optional, and it goes out with the notice.',
                  errorText: _failure?.firstMessageFor('reason'),
                ),
                validator: decision.demandsAReason
                    ? Validators.rejectionReason
                    : Validators.decisionNote,
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.all(AppSpacing.lg),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Leave it waiting'),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          style: decision.demandsAReason ? _destructive : null,
          onPressed: _isSaving ? null : _submit,
          child: Text(_isSaving ? decision.working : decision.verb),
        ),
      ],
    );
  }

  String get _whatHappens {
    final String who = widget.application.applicantName;

    return switch (widget.decision) {
      ApplicationDecision.approve =>
        '$who is given the Host role and told. Their session ends, and they '
            'sign back in able to list.',
      ApplicationDecision.reject =>
        '$who keeps the account they have and is told the request was turned '
            'down, in the words below. Nothing stops them applying again.',
    };
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _failure = null;
      _isSaving = true;
    });

    final ApiException? refused = await widget.decide(_reason.text.trim());

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

  static final ButtonStyle _destructive = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) =>
          states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)
          ? AppColors.dangerDeep
          : AppColors.danger,
    ),
  );
}
