import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/forms/form_fields.dart';
import '../../../core/forms/form_validation.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/password_field.dart';
import '../data/auth_repository.dart';
import 'auth_layout.dart';
import 'reset_password_notifier.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ResetPasswordNotifier>(
      create: (BuildContext context) =>
          ResetPasswordNotifier(context.read<AuthRepository>()),
      child: const _ResetPasswordForm(),
    );
  }
}

class _ResetPasswordForm extends StatefulWidget {
  const _ResetPasswordForm();

  @override
  State<_ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<_ResetPasswordForm>
    with FormValidation<_ResetPasswordForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  // The code is sent under the name the server binds it to, so a refusal of
  // it lands on this field rather than in the band above the form.
  final FormFields _fields = FormFields(<String>[
    'token',
    'newPassword',
    'confirmNewPassword',
  ]);

  final TextEditingController _code = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmNewPassword = TextEditingController();

  late final List<TextEditingController> _typed = <TextEditingController>[
    _code,
    _newPassword,
    _confirmNewPassword,
  ];

  @override
  void initState() {
    super.initState();

    for (final TextEditingController field in _typed) {
      field.addListener(_typingChanged);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController field in _typed) {
      field
        ..removeListener(_typingChanged)
        ..dispose();
    }

    super.dispose();
  }

  bool get _hasInput =>
      _typed.any((TextEditingController field) => field.text.isNotEmpty);

  void _typingChanged() => setState(() {});

  static String? _codeIsThere(String? value) =>
      value == null || value.trim().isEmpty
      ? 'Enter the code from the email.'
      : null;

  // A reset issues no token, so the way back is the sign in screen the flow
  // started on rather than a session this screen could begin.
  Future<void> _submit() async {
    if (!validate(_form, _fields)) {
      return;
    }

    final ResetPasswordNotifier notifier = context
        .read<ResetPasswordNotifier>();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    await notifier.reset(
      code: _code.text.trim(),
      newPassword: _newPassword.text,
      confirmNewPassword: _confirmNewPassword.text,
    );

    if (notifier.failure case final ApiException failure) {
      _fields.revealFault(failure);

      return;
    }

    if (notifier.wasReset && navigator.mounted) {
      navigator.popUntil((Route<dynamic> route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your password was changed. Sign in with it.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ResetPasswordNotifier notifier = context
        .watch<ResetPasswordNotifier>();
    final TextTheme text = Theme.of(context).textTheme;
    final bool isBusy = notifier.isBusy;

    return DiscardGuard(
      hasInput: _hasInput && !isBusy,
      child: AuthLayout(
        appBar: AppBar(),
        children: <Widget>[
          Text('Choose a new password', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The code is in the email that was just sent. It works once, and '
            'only for a day.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (notifier.failure?.message case final String message) ...<Widget>[
            AppNotice(message),
            const SizedBox(height: AppSpacing.lg),
          ],
          Form(
            key: _form,
            autovalidateMode: validation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  key: _fields['token'],
                  controller: _code,
                  enabled: !isBusy,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Code',
                    errorText: notifier.messageFor('token'),
                  ),
                  validator: _codeIsThere,
                ),
                const SizedBox(height: AppSpacing.lg),
                PasswordField(
                  fieldKey: _fields['newPassword'],
                  controller: _newPassword,
                  label: 'New password',
                  enabled: !isBusy,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  errorText: notifier.messageFor('newPassword'),
                  validator: (String? value) => Validators.newPassword(
                    value,
                    missing: 'Enter a new password.',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PasswordField(
                  fieldKey: _fields['confirmNewPassword'],
                  controller: _confirmNewPassword,
                  label: 'Repeat the new password',
                  enabled: !isBusy,
                  textInputAction: TextInputAction.done,
                  errorText: notifier.messageFor('confirmNewPassword'),
                  validator: (String? value) => Validators.repeatedPassword(
                    value,
                    _newPassword.text,
                    missing: 'Repeat the new password.',
                  ),
                  onSubmitted: _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: isBusy ? null : _submit,
            child: Text(isBusy ? 'Changing the password' : 'Change password'),
          ),
        ],
      ),
    );
  }
}
