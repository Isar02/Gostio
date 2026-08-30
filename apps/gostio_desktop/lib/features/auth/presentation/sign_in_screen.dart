import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/tone.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_notice.dart';
import '../data/auth_repository.dart';
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

class _SignInFormState extends State<_SignInForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }

    await context.read<SignInNotifier>().signIn(
      username: _username.text.trim(),
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final SignInNotifier notifier = context.watch<SignInNotifier>();
    final SessionEnding? ending = context.select<Session, SessionEnding?>(
      (Session s) => s.lastEnding,
    );

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.panel),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.large,
                border: Border.all(color: AppColors.border),
              ),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Gostio',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Administration and hosting.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (ending == SessionEnding.tokenDied) ...<Widget>[
                      const AppNotice(
                        'Your session ended. Sign in again.',
                        tone: Tone.informative,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (notifier.failureMessage
                        case final String message) ...<Widget>[
                      AppNotice(message),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    TextFormField(
                      controller: _username,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      enabled: !notifier.isBusy,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        errorText: notifier.messageFor('username'),
                      ),
                      validator: Validators.username,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      enabled: !notifier.isBusy,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        errorText: notifier.messageFor('password'),
                      ),
                      validator: Validators.password,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: notifier.isBusy ? null : _submit,
                      child: Text(notifier.isBusy ? 'Signing in' : 'Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
