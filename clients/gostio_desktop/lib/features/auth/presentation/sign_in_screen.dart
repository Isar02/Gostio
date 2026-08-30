import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/session/session.dart';
import '../../../core/validation/validators.dart';
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
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Gostio',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  if (ending == SessionEnding.tokenDied)
                    const _Notice('Your session ended. Sign in again.'),
                  if (notifier.failureMessage case final String message)
                    _Notice(message),
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
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 24),
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
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        message,
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }
}
