import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/forms/form_fields.dart';
import '../../../core/forms/form_validation.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/password_field.dart';
import '../data/auth_repository.dart';
import 'auth_layout.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'sign_in_notifier.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SignInNotifier>(
      create: (BuildContext context) => SignInNotifier(
        context.read<AuthRepository>(),
        context.read<Session>(),
      ),
      child: const _SignInForm(),
    );
  }
}

class _SignInForm extends StatefulWidget {
  const _SignInForm();

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm>
    with FormValidation<_SignInForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final FormFields _fields = FormFields(<String>['username', 'password']);
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (!validate(_form, _fields)) {
      return;
    }

    final SignInNotifier notifier = context.read<SignInNotifier>();

    await notifier.signIn(
      username: _username.text.trim(),
      password: _password.text,
    );

    if (notifier.failure case final ApiException failure) {
      _fields.revealFault(failure);
    }
  }

  Future<void> _open(Widget screen) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (BuildContext context) => screen),
  );

  @override
  Widget build(BuildContext context) {
    final SignInNotifier notifier = context.watch<SignInNotifier>();
    final TextTheme text = Theme.of(context).textTheme;
    final SessionEnding? ending = context.select<Session, SessionEnding?>(
      (Session session) => session.lastEnding,
    );

    return AuthLayout(
      children: <Widget>[
        const Align(alignment: Alignment.centerLeft, child: BrandMark()),
        const SizedBox(height: AppSpacing.xl),
        Text('Gostio', style: text.displaySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Stays and experiences across Bosnia and Herzegovina.',
          style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (ending == SessionEnding.tokenDied) ...<Widget>[
          const AppNotice(
            'Your session ended. Sign in again.',
            tone: Tone.informative,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (notifier.failure?.message case final String message) ...<Widget>[
          AppNotice(message),
          const SizedBox(height: AppSpacing.lg),
        ],
        Form(
          key: _form,
          autovalidateMode: validation,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  key: _fields['username'],
                  controller: _username,
                  enabled: !notifier.isBusy,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.username],
                  decoration: InputDecoration(
                    labelText: 'Username',
                    errorText: notifier.messageFor('username'),
                  ),
                  validator: Validators.username,
                  onChanged: (_) => notifier.clearFailureFor('username'),
                ),
                const SizedBox(height: AppSpacing.lg),
                PasswordField(
                  fieldKey: _fields['password'],
                  controller: _password,
                  label: 'Password',
                  enabled: !notifier.isBusy,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.password],
                  errorText: notifier.messageFor('password'),
                  validator: Validators.password,
                  onChanged: (_) => notifier.clearFailureFor('password'),
                  onSubmitted: _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: notifier.isBusy
                ? null
                : () => _open(const ForgotPasswordScreen()),
            child: const Text('Forgot your password?'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: notifier.isBusy ? null : _submit,
          child: Text(notifier.isBusy ? 'Signing in' : 'Sign in'),
        ),
        const SizedBox(height: AppSpacing.xxl),
        const Divider(),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'New to Gostio?',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: notifier.isBusy
              ? null
              : () => _open(const RegisterScreen()),
          child: const Text('Create an account'),
        ),
      ],
    );
  }
}
