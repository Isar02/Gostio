import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/forms/form_fields.dart';
import '../../../core/forms/form_validation.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/discard_guard.dart';
import '../data/profile_draft.dart';
import '../data/profile_repository.dart';
import 'profile_details_notifier.dart';
import 'profile_write_lock.dart';

// What the account is called and where it is reached. The username is not on
// this form — it is written once, when the account is made — and neither are
// the roles, which are an administrator's to change.
class ProfileDetailsScreen extends StatelessWidget {
  const ProfileDetailsScreen({required this.account, super.key});

  static Future<void> open(BuildContext context, User account) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              ProfileDetailsScreen(account: account),
        ),
      );

  final User account;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileDetailsNotifier>(
      create: (BuildContext context) => ProfileDetailsNotifier(
        context.read<ProfileRepository>(),
        context.read<Session>(),
        context.read<ProfileWriteLock>(),
      ),
      child: _DetailsForm(account),
    );
  }
}

class _DetailsForm extends StatefulWidget {
  const _DetailsForm(this.account);

  final User account;

  @override
  State<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends State<_DetailsForm>
    with FormValidation<_DetailsForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final FormFields _fields = FormFields(<String>[
    'firstName',
    'lastName',
    'email',
    'phoneNumber',
  ]);

  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phoneNumber = TextEditingController();

  late final List<TextEditingController> _typed = <TextEditingController>[
    _firstName,
    _lastName,
    _email,
    _phoneNumber,
  ];

  @override
  void initState() {
    super.initState();

    // The account as it stands is what the form opens on, so this is editing
    // what is there rather than writing it out again.
    _firstName.text = widget.account.firstName;
    _lastName.text = widget.account.lastName;
    _email.text = widget.account.email;
    _phoneNumber.text = widget.account.phoneNumber ?? '';

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
    final ProfileDetailsNotifier details = context
        .watch<ProfileDetailsNotifier>();
    final bool isWriting = context.watch<ProfileWriteLock>().isWriting;
    final bool isBusy = details.isBusy;

    return DiscardGuard(
      hasInput: _hasChanges && !isBusy,
      title: 'Leave your details?',
      message: 'What you have changed will not be saved.',
      child: Scaffold(
        appBar: AppBar(title: const Text('Your details')),
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
                      if (details.failure?.message
                          case final String message) ...<Widget>[
                        AppNotice(message),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      TextFormField(
                        key: _fields['firstName'],
                        controller: _firstName,
                        enabled: !isBusy,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[AutofillHints.givenName],
                        decoration: InputDecoration(
                          labelText: 'First name',
                          errorText: details.messageFor('firstName'),
                        ),
                        validator: Validators.firstName,
                        onChanged: (_) => details.clearFailureFor('firstName'),
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
                          errorText: details.messageFor('lastName'),
                        ),
                        validator: Validators.lastName,
                        onChanged: (_) => details.clearFailureFor('lastName'),
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
                          helperText:
                              'You sign in with it, and a reset is sent to it.',
                          errorText: details.messageFor('email'),
                        ),
                        validator: Validators.emailAddress,
                        onChanged: (_) => details.clearFailureFor('email'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        key: _fields['phoneNumber'],
                        controller: _phoneNumber,
                        enabled: !isBusy,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        autofillHints: const <String>[
                          AutofillHints.telephoneNumber,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Phone number',
                          helperText: 'Optional. A host reaches you on it.',
                          errorText: details.messageFor('phoneNumber'),
                        ),
                        validator: Validators.phoneNumber,
                        onChanged: (_) =>
                            details.clearFailureFor('phoneNumber'),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          // A form holding what the account already says has nothing to send,
          // and a button that has to be pressed to learn that is one that lied.
          action: FilledButton(
            onPressed: !_hasChanges || isWriting ? null : _submit,
            child: Text(isBusy ? 'Saving' : 'Save changes'),
          ),
        ),
      ),
    );
  }

  ProfileDraft get _draft {
    final String typed = _phoneNumber.text.trim();

    return ProfileDraft(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      phoneNumber: typed.isEmpty ? null : typed,
    );
  }

  bool get _hasChanges => !_draft.hasSameFieldsAs(widget.account);

  void _typingChanged() => setState(() {});

  Future<void> _submit() async {
    if (!validate(_form, _fields)) {
      return;
    }

    final ProfileDetailsNotifier details = context
        .read<ProfileDetailsNotifier>();
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    if (!await details.save(_draft)) {
      if (details.failure case final ApiException failure) {
        _fields.revealFault(failure);
      }

      return;
    }

    // What is behind this route is already drawing the account that was
    // saved, so leaving is what shows it.
    if (navigator.mounted) {
      navigator.pop();
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Your details were saved.')),
    );
  }
}
