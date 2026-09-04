import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/forms/form_fields.dart';
import '../../../core/forms/form_validation.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/password_field.dart';
import '../data/account_registration.dart';
import '../data/auth_repository.dart';
import 'auth_layout.dart';
import 'register_notifier.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RegisterNotifier>(
      create: (BuildContext context) => RegisterNotifier(
        context.read<AuthRepository>(),
        context.read<Session>(),
      ),
      child: const _RegisterForm(),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm>
    with FormValidation<_RegisterForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final FormFields _fields = FormFields(<String>[
    'firstName',
    'lastName',
    'username',
    'email',
    'phoneNumber',
    'password',
    'confirmPassword',
  ]);

  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phoneNumber = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  late final List<TextEditingController> _typed = <TextEditingController>[
    _firstName,
    _lastName,
    _username,
    _email,
    _phoneNumber,
    _password,
    _confirmPassword,
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

  // What Back does depends on whether the form still holds anything, so the
  // answer is read while the form is drawn rather than when it is left.
  bool get _hasInput =>
      _typed.any((TextEditingController field) => field.text.isNotEmpty);

  void _typingChanged() => setState(() {});

  Future<void> _submit() async {
    if (!validate(_form, _fields)) {
      return;
    }

    final RegisterNotifier notifier = context.read<RegisterNotifier>();
    final NavigatorState navigator = Navigator.of(context);
    final String phoneNumber = _phoneNumber.text.trim();

    final bool wasRegistered = await notifier.register(
      AccountRegistration(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        username: _username.text.trim(),
        email: _email.text.trim(),
        phoneNumber: phoneNumber.isEmpty ? null : phoneNumber,
        password: _password.text,
        confirmPassword: _confirmPassword.text,
      ),
    );

    if (!wasRegistered) {
      if (notifier.failure case final ApiException failure) {
        _fields.revealFault(failure);
      }

      return;
    }

    // The session the registration began is drawn under this route rather than
    // over it, so the form has to leave for the account to be seen.
    if (navigator.mounted) {
      navigator.popUntil((Route<dynamic> route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final RegisterNotifier notifier = context.watch<RegisterNotifier>();
    final TextTheme text = Theme.of(context).textTheme;
    final bool isBusy = notifier.isBusy;

    return DiscardGuard(
      hasInput: _hasInput,
      child: AuthLayout(
        appBar: AppBar(),
        children: <Widget>[
          Text('Create an account', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'One account books stays and experiences, and keeps the messages '
            'about them.',
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
                  key: _fields['firstName'],
                  controller: _firstName,
                  enabled: !isBusy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.givenName],
                  decoration: InputDecoration(
                    labelText: 'First name',
                    errorText: notifier.messageFor('firstName'),
                  ),
                  validator: Validators.firstName,
                  onChanged: (_) => notifier.clearFailureFor('firstName'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: _fields['lastName'],
                  controller: _lastName,
                  enabled: !isBusy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.familyName],
                  decoration: InputDecoration(
                    labelText: 'Last name',
                    errorText: notifier.messageFor('lastName'),
                  ),
                  validator: Validators.lastName,
                  onChanged: (_) => notifier.clearFailureFor('lastName'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: _fields['username'],
                  controller: _username,
                  enabled: !isBusy,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.newUsername],
                  decoration: InputDecoration(
                    labelText: 'Username',
                    errorText: notifier.messageFor('username'),
                  ),
                  validator: Validators.accountUsername,
                  onChanged: (_) => notifier.clearFailureFor('username'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: _fields['email'],
                  controller: _email,
                  enabled: !isBusy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Email',
                    errorText: notifier.messageFor('email'),
                  ),
                  validator: Validators.emailAddress,
                  onChanged: (_) => notifier.clearFailureFor('email'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: _fields['phoneNumber'],
                  controller: _phoneNumber,
                  enabled: !isBusy,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.telephoneNumber],
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    helperText: 'Optional. A host reaches you on it.',
                    errorText: notifier.messageFor('phoneNumber'),
                  ),
                  validator: Validators.phoneNumber,
                  onChanged: (_) => notifier.clearFailureFor('phoneNumber'),
                ),
                const SizedBox(height: AppSpacing.lg),
                PasswordField(
                  fieldKey: _fields['password'],
                  controller: _password,
                  label: 'Password',
                  enabled: !isBusy,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  errorText: notifier.messageFor('password'),
                  validator: (String? value) => Validators.newPassword(
                    value,
                    missing: 'Enter a password.',
                  ),
                  onChanged: (_) => notifier.clearFailureFor('password'),
                ),
                const SizedBox(height: AppSpacing.lg),
                PasswordField(
                  fieldKey: _fields['confirmPassword'],
                  controller: _confirmPassword,
                  label: 'Repeat the password',
                  enabled: !isBusy,
                  textInputAction: TextInputAction.done,
                  errorText: notifier.messageFor('confirmPassword'),
                  validator: (String? value) => Validators.repeatedPassword(
                    value,
                    _password.text,
                    missing: 'Repeat the password.',
                  ),
                  onChanged: (_) => notifier.clearFailureFor('confirmPassword'),
                  onSubmitted: _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: isBusy ? null : _submit,
            child: Text(isBusy ? 'Creating the account' : 'Create account'),
          ),
        ],
      ),
    );
  }
}
