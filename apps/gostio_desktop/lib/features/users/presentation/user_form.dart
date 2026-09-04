import 'package:flutter/material.dart';

import '../../../core/models/user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/multi_select_field.dart';
import '../../reference/data/lookup_item.dart';
import '../data/user_draft.dart';
import 'user_detail_notifier.dart';

class UserForm extends StatefulWidget {
  const UserForm({
    required this.notifier,
    required this.onSaved,
    required this.onDeleted,
    super.key,
  });

  final UserDetailNotifier notifier;
  final ValueChanged<User> onSaved;
  final ValueChanged<User> onDeleted;

  @override
  State<UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _repeat = TextEditingController();

  Set<LookupItem> _roles = <LookupItem>{};
  bool _isActive = true;
  bool _isChangingPassword = false;

  // A multi-select cannot fault itself through Form, so what it is missing is
  // held here and written under the control it belongs to.
  final Map<String, String> _faults = <String, String>{};

  @override
  void initState() {
    super.initState();

    final User? account = widget.notifier.user;
    if (account == null) {
      return;
    }

    _firstName.text = account.firstName;
    _lastName.text = account.lastName;
    _email.text = account.email;
    _phone.text = account.phoneNumber ?? '';
    _isActive = account.isActive;
    _roles = widget.notifier.roles
        .where((LookupItem role) => account.hasRole(role.name))
        .toSet();
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _firstName,
      _lastName,
      _username,
      _email,
      _phone,
      _password,
      _repeat,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  // A new account is given its password where it is made; an existing one is
  // only asked for one once somebody says they are changing it.
  bool get _wantsPassword => widget.notifier.isCreating || _isChangingPassword;

  @override
  Widget build(BuildContext context) {
    final UserDetailNotifier notifier = widget.notifier;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (notifier.writeFailureMessage
                case final String message) ...<Widget>[
              AppNotice(message),
              const SizedBox(height: AppSpacing.lg),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _identity(notifier)),
                const SizedBox(width: AppSpacing.xl),
                Expanded(child: _standing(notifier)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _Actions(
              notifier: notifier,
              onSave: _submit,
              onDelete: _confirmDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _identity(UserDetailNotifier notifier) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _firstName,
              decoration: InputDecoration(
                labelText: 'First name',
                errorText: notifier.messageFor('firstName'),
              ),
              validator: Validators.firstName,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextFormField(
              controller: _lastName,
              decoration: InputDecoration(
                labelText: 'Last name',
                errorText: notifier.messageFor('lastName'),
              ),
              validator: Validators.lastName,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      // The username is written once. An account that exists carries it in the
      // header rather than in a field nothing can be typed into.
      if (notifier.isCreating) ...<Widget>[
        TextFormField(
          controller: _username,
          decoration: InputDecoration(
            labelText: 'Username',
            helperText:
                'What they sign in with, and it is not changed afterwards.',
            errorText: notifier.messageFor('username'),
          ),
          validator: Validators.accountUsername,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      TextFormField(
        controller: _email,
        decoration: InputDecoration(
          labelText: 'Email',
          errorText: notifier.messageFor('email'),
        ),
        validator: Validators.emailAddress,
      ),
      const SizedBox(height: AppSpacing.lg),
      TextFormField(
        controller: _phone,
        decoration: InputDecoration(
          labelText: 'Phone number',
          helperText: 'Optional, with a country code or as 061 234 567.',
          errorText: notifier.messageFor('phoneNumber'),
        ),
        validator: Validators.phoneNumber,
      ),
    ],
  );

  Widget _standing(UserDetailNotifier notifier) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      MultiSelectField<LookupItem>(
        label: 'Roles',
        emptyLabel: 'Choose at least one',
        values: notifier.roles,
        selected: _roles,
        labels: (LookupItem role) => role.name,
        errorText: _faults['roles'] ?? notifier.messageFor('roles'),
        onChanged: (Set<LookupItem> chosen) => setState(() => _roles = chosen),
      ),
      const SizedBox(height: AppSpacing.xs),
      _Footnote(
        notifier.isCreating
            ? 'What the account may reach. A host account is also made by '
                  'approving a host application.'
            : 'Changing what an account holds signs it out, and it comes back '
                  'with the roles it now has.',
      ),
      if (!notifier.isCreating) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        _Active(
          isActive: _isActive,
          isSelf: notifier.isSelf,
          onChanged: (bool active) => setState(() => _isActive = active),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ChangePassword(
          isSelf: notifier.isSelf,
          isChanging: _isChangingPassword,
          onChanged: _changePassword,
        ),
      ],
      if (_wantsPassword) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(
            labelText: notifier.isCreating ? 'Password' : 'New password',
            helperText:
                'At least ${Validators.passwordMinimumLength} characters.',
            errorText: notifier.messageFor(_passwordField),
          ),
          validator: (String? value) => Validators.newPassword(
            value,
            missing: notifier.isCreating
                ? 'Enter a password.'
                : 'Enter a new password.',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _repeat,
          obscureText: true,
          decoration: InputDecoration(
            labelText: notifier.isCreating
                ? 'Repeat the password'
                : 'Repeat the new password',
            errorText: notifier.messageFor(_confirmationField),
          ),
          validator: (String? value) => Validators.repeatedPassword(
            value,
            _password.text,
            missing: notifier.isCreating
                ? 'Repeat the password.'
                : 'Repeat the new password.',
          ),
        ),
      ],
    ],
  );

  // The two endpoints key the same pair of fields differently, and a message
  // the server sent has to land under the control it is about.
  String get _passwordField =>
      widget.notifier.isCreating ? 'password' : 'newPassword';

  String get _confirmationField =>
      widget.notifier.isCreating ? 'confirmPassword' : 'confirmNewPassword';

  void _changePassword(bool changing) => setState(() {
    _isChangingPassword = changing;

    if (!changing) {
      _password.clear();
      _repeat.clear();
    }
  });

  Future<void> _submit() async {
    final bool written = _form.currentState?.validate() ?? false;

    setState(() {
      _faults
        ..clear()
        ..addAll(<String, String>{
          if (_roles.isEmpty) 'roles': 'Give the account at least one role.',
        });
    });

    if (!written || _faults.isNotEmpty) {
      return;
    }

    final UserDetailNotifier notifier = widget.notifier;
    final UserDraft draft = UserDraft(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      phoneNumber: _typedPhoneNumber,
    );
    final List<String> roles = <String>[
      for (final LookupItem role in _roles) role.name,
    ];

    final User? saved = notifier.isCreating
        ? await notifier.create(
            draft,
            username: _username.text.trim(),
            password: _password.text,
            confirmPassword: _repeat.text,
            roles: roles,
          )
        : await notifier.saveChanges(
            draft,
            roles: roles,
            isActive: _isActive,
            password: _isChangingPassword ? _password.text : null,
            confirmPassword: _isChangingPassword ? _repeat.text : null,
          );

    // Back during the save takes the screen the callback would reach for, and
    // the notifier's own guard does not cover a context.
    if (saved == null || !mounted) {
      return;
    }

    if (notifier.isCreating) {
      _reset();
    } else if (_isChangingPassword) {
      _changePassword(false);
    }

    widget.onSaved(saved);
  }

  String? get _typedPhoneNumber {
    final String typed = _phone.text.trim();

    return typed.isEmpty ? null : typed;
  }

  // An account that has just been made leaves the form empty for the next one
  // rather than sitting there looking like it is still being written.
  void _reset() {
    _form.currentState?.reset();

    setState(() {
      _firstName.clear();
      _lastName.clear();
      _username.clear();
      _email.clear();
      _phone.clear();
      _password.clear();
      _repeat.clear();
      _roles = <LookupItem>{};
      _faults.clear();
    });
  }

  Future<void> _confirmDelete() async {
    final User? account = widget.notifier.user;
    if (account == null) {
      return;
    }

    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Delete ${account.fullName}?',
      message:
          'The account goes, and so does everything that can go with it. One '
          'that owns records the platform has to keep cannot be deleted — '
          'deactivate it instead. This cannot be undone.',
      confirmLabel: 'Delete account',
      isDestructive: true,
    );

    if (!agreed) {
      return;
    }

    final bool gone = await widget.notifier.delete();

    if (gone && mounted) {
      widget.onDeleted(account);
    }
  }
}

class _Active extends StatelessWidget {
  const _Active({
    required this.isActive,
    required this.isSelf,
    required this.onChanged,
  });

  final bool isActive;
  final bool isSelf;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Tooltip(
      message: isSelf
          ? 'An account cannot deactivate itself. Ask another administrator.'
          : 'A deactivated account keeps everything it owns and cannot sign '
                'in.',
      child: SwitchListTile(
        value: isActive,
        onChanged: isSelf ? null : onChanged,
        contentPadding: EdgeInsets.zero,
        title: Text('Active', style: text.bodyMedium),
        subtitle: Text(
          isActive
              ? 'They can sign in and use the platform.'
              : 'Deactivated: signed out at once, and shut out until this '
                    'goes back on.',
          style: text.bodySmall,
        ),
      ),
    );
  }
}

class _ChangePassword extends StatelessWidget {
  const _ChangePassword({
    required this.isSelf,
    required this.isChanging,
    required this.onChanged,
  });

  final bool isSelf;
  final bool isChanging;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Tooltip(
      message: isSelf
          ? 'Your own password is changed under Profile, where the one you '
                'sign in with now is asked for.'
          : 'The account is signed out and signs back in with what is typed '
                'here. Nobody is sent it.',
      child: SwitchListTile(
        value: isChanging,
        onChanged: isSelf ? null : onChanged,
        contentPadding: EdgeInsets.zero,
        title: Text('Set a new password', style: text.bodyMedium),
        subtitle: Text(
          'Left off, the password they have stays as it is.',
          style: text.bodySmall,
        ),
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: AppColors.inkFaint),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.notifier,
    required this.onSave,
    required this.onDelete,
  });

  final UserDetailNotifier notifier;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (!notifier.isCreating)
          Tooltip(
            message: notifier.isSelf
                ? 'An account cannot delete itself. Ask another administrator.'
                : 'Delete this account and everything that can go with it.',
            child: OutlinedButton(
              onPressed: notifier.isSelf || notifier.isSaving ? null : onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              child: const Text('Delete'),
            ),
          ),
        const Spacer(),
        FilledButton(
          onPressed: notifier.isSaving ? null : onSave,
          child: Text(_label(notifier)),
        ),
      ],
    );
  }

  static String _label(UserDetailNotifier notifier) {
    if (notifier.isSaving) {
      return notifier.isCreating ? 'Creating' : 'Saving';
    }

    return notifier.isCreating ? 'Create account' : 'Save changes';
  }
}
