import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/forms/form_fields.dart';
import '../../../core/forms/form_validation.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/discard_guard.dart';
import '../data/auth_repository.dart';
import 'auth_layout.dart';
import 'forgot_password_notifier.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ForgotPasswordNotifier>(
      create: (BuildContext context) =>
          ForgotPasswordNotifier(context.read<AuthRepository>()),
      child: const _ForgotPasswordForm(),
    );
  }
}

class _ForgotPasswordForm extends StatefulWidget {
  const _ForgotPasswordForm();

  @override
  State<_ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<_ForgotPasswordForm>
    with FormValidation<_ForgotPasswordForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final FormFields _fields = FormFields(<String>['email']);
  final TextEditingController _email = TextEditingController();

  @override
  void initState() {
    super.initState();

    _email.addListener(_typingChanged);
  }

  @override
  void dispose() {
    _email
      ..removeListener(_typingChanged)
      ..dispose();

    super.dispose();
  }

  void _typingChanged() => setState(() {});

  Future<void> _submit() async {
    if (!validate(_form, _fields)) {
      return;
    }

    final ForgotPasswordNotifier notifier = context
        .read<ForgotPasswordNotifier>();

    await notifier.ask(_email.text.trim());

    if (notifier.failure case final ApiException failure) {
      _fields.revealFault(failure);
    }
  }

  void _openTheReset() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const ResetPasswordScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ForgotPasswordNotifier notifier = context
        .watch<ForgotPasswordNotifier>();
    final TextTheme text = Theme.of(context).textTheme;
    final bool isBusy = notifier.isBusy;

    return DiscardGuard(
      hasInput: _email.text.isNotEmpty && !notifier.wasAsked && !isBusy,
      child: AuthLayout(
        appBar: AppBar(),
        children: <Widget>[
          Text('Reset your password', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enter the address your account is registered to. A code comes '
            'back by email, and the next screen takes it.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (notifier.failure?.message case final String message) ...<Widget>[
            AppNotice(message),
            const SizedBox(height: AppSpacing.lg),
          ],
          // The API answers the same either way, so this says what was asked
          // rather than claiming an account exists.
          if (notifier.wasAsked) ...<Widget>[
            const AppNotice(
              'If an account is registered to that address, a code is on its '
              'way to it. Check the spam folder before asking again.',
              tone: Tone.informative,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Form(
            key: _form,
            autovalidateMode: validation,
            child: TextFormField(
              key: _fields['email'],
              controller: _email,
              enabled: !isBusy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: notifier.messageFor('email'),
              ),
              validator: Validators.emailAddress,
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (notifier.wasAsked) ...<Widget>[
            FilledButton(
              onPressed: isBusy ? null : _openTheReset,
              child: const Text('Enter the code'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: isBusy ? null : _submit,
              child: Text(isBusy ? 'Sending' : 'Send it again'),
            ),
          ] else
            FilledButton(
              onPressed: isBusy ? null : _submit,
              child: Text(isBusy ? 'Sending' : 'Send the code'),
            ),
        ],
      ),
    );
  }
}
