import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import 'profile_notifier.dart';

// The current password is asked for because this is the account asking about
// itself. An administrator setting somebody else's is the other endpoint, and
// it is the one that does not ask.
class ProfilePasswordForm extends StatefulWidget {
  const ProfilePasswordForm({
    required this.notifier,
    required this.onChanged,
    super.key,
  });

  final ProfileNotifier notifier;
  final VoidCallback onChanged;

  @override
  State<ProfilePasswordForm> createState() => _ProfilePasswordFormState();
}

class _ProfilePasswordFormState extends State<ProfilePasswordForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _repeat = TextEditingController();

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _current,
      _next,
      _repeat,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProfileNotifier notifier = widget.notifier;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (notifier.passwordFailureMessage
              case final String message) ...<Widget>[
            AppNotice(message),
            const SizedBox(height: AppSpacing.lg),
          ],
          TextFormField(
            controller: _current,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Current password',
              errorText: notifier.passwordMessageFor('currentPassword'),
            ),
            validator: Validators.currentPassword,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _next,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'New password',
              helperText:
                  'At least ${Validators.passwordMinimumLength} characters.',
              errorText: notifier.passwordMessageFor('newPassword'),
            ),
            validator: (String? value) =>
                Validators.newPassword(value, missing: 'Enter a new password.'),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _repeat,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Repeat the new password',
              errorText: notifier.passwordMessageFor('confirmNewPassword'),
            ),
            validator: (String? value) => Validators.repeatedPassword(
              value,
              _next.text,
              missing: 'Repeat the new password.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You stay signed in here. Every other window signed in as you is '
            'signed out.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkFaint),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: notifier.isWriting ? null : _submit,
              child: Text(
                notifier.isSavingPassword ? 'Changing' : 'Change password',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }

    final bool changed = await widget.notifier.changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
      confirmNewPassword: _repeat.text,
    );

    if (!changed || !mounted) {
      return;
    }

    // Nothing on this form is worth keeping once it has been written, and a
    // password left sitting in a field is a password on the screen.
    _form.currentState?.reset();

    setState(() {
      _current.clear();
      _next.clear();
      _repeat.clear();
    });

    widget.onChanged();
  }
}
