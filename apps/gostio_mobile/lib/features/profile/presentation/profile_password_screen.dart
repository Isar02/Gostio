import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/forms/form_fields.dart';
import '../../../core/forms/form_validation.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/password_field.dart';
import '../data/password_draft.dart';
import '../data/profile_repository.dart';
import 'profile_password_notifier.dart';
import 'profile_write_lock.dart';

// The current password is asked for because this is the account asking about
// itself. Somebody who forgot it has the mailed reset instead, and an
// administrator setting another account's is the endpoint that does not ask.
class ProfilePasswordScreen extends StatelessWidget {
  const ProfilePasswordScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const ProfilePasswordScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfilePasswordNotifier>(
      create: (BuildContext context) => ProfilePasswordNotifier(
        context.read<ProfileRepository>(),
        context.read<Session>(),
        context.read<ProfileWriteLock>(),
      ),
      child: const _PasswordForm(),
    );
  }
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm();

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm>
    with FormValidation<_PasswordForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final FormFields _fields = FormFields(<String>[
    'currentPassword',
    'newPassword',
    'confirmNewPassword',
  ]);

  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _repeat = TextEditingController();

  late final List<TextEditingController> _typed = <TextEditingController>[
    _current,
    _next,
    _repeat,
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

  @override
  Widget build(BuildContext context) {
    final ProfilePasswordNotifier password = context
        .watch<ProfilePasswordNotifier>();
    final bool isWriting = context.watch<ProfileWriteLock>().isWriting;
    final bool isBusy = password.isBusy;
    final TextTheme text = Theme.of(context).textTheme;

    return DiscardGuard(
      hasInput: _hasInput && !isBusy,
      title: 'Leave this form?',
      message: 'Your password has not been changed.',
      child: Scaffold(
        appBar: AppBar(title: const Text('Password')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.formColumn,
                ),
                child: Form(
                  key: _form,
                  autovalidateMode: validation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (password.failure?.message
                          case final String message) ...<Widget>[
                        AppNotice(message),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      PasswordField(
                        fieldKey: _fields['currentPassword'],
                        controller: _current,
                        label: 'Current password',
                        enabled: !isBusy,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[AutofillHints.password],
                        errorText: password.messageFor('currentPassword'),
                        validator: Validators.currentPassword,
                        onChanged: (_) =>
                            password.clearFailureFor('currentPassword'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PasswordField(
                        fieldKey: _fields['newPassword'],
                        controller: _next,
                        label: 'New password',
                        enabled: !isBusy,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[
                          AutofillHints.newPassword,
                        ],
                        errorText: password.messageFor('newPassword'),
                        validator: (String? value) => Validators.newPassword(
                          value,
                          missing: 'Enter a new password.',
                        ),
                        onChanged: (_) =>
                            password.clearFailureFor('newPassword'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'At least ${Validators.passwordMinimumLength} '
                        'characters.',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.inkFaint,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PasswordField(
                        fieldKey: _fields['confirmNewPassword'],
                        controller: _repeat,
                        label: 'Repeat the new password',
                        enabled: !isBusy,
                        textInputAction: TextInputAction.done,
                        errorText: password.messageFor('confirmNewPassword'),
                        validator: (String? value) =>
                            Validators.repeatedPassword(
                              value,
                              _next.text,
                              missing: 'Repeat the new password.',
                            ),
                        onChanged: (_) =>
                            password.clearFailureFor('confirmNewPassword'),
                        onSubmitted: _submit,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'You stay signed in on this phone. Anywhere else '
                        'signed in as you is signed out.',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          action: FilledButton(
            onPressed: isWriting ? null : _submit,
            child: Text(isBusy ? 'Changing' : 'Change password'),
          ),
        ),
      ),
    );
  }

  bool get _hasInput =>
      _typed.any((TextEditingController field) => field.text.isNotEmpty);

  void _typingChanged() => setState(() {});

  Future<void> _submit() async {
    if (!validate(_form, _fields)) {
      return;
    }

    final ProfilePasswordNotifier password = context
        .read<ProfilePasswordNotifier>();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool changed = await password.change(
      PasswordDraft(
        currentPassword: _current.text,
        newPassword: _next.text,
        confirmNewPassword: _repeat.text,
      ),
    );

    if (!changed) {
      if (password.failure case final ApiException failure) {
        _fields.revealFault(failure);
      }

      return;
    }

    // Nothing on this form is worth keeping once it has been written, and it
    // is cleared before the route goes so that a password is not left sitting
    // in a field through the closing frames.
    for (final TextEditingController field in _typed) {
      field.clear();
    }

    if (navigator.mounted) {
      navigator.pop();
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Your password was changed.')),
    );
  }
}
