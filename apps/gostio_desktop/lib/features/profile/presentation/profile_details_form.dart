import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../users/data/user_draft.dart';
import 'profile_notifier.dart';

// The four fields an account may write about itself. The username and the
// roles are not among them: one is never written again, and the other is an
// administrator's to change.
class ProfileDetailsForm extends StatefulWidget {
  const ProfileDetailsForm({
    required this.notifier,
    required this.account,
    required this.onSaved,
    super.key,
  });

  final ProfileNotifier notifier;
  final User account;
  final VoidCallback onSaved;

  @override
  State<ProfileDetailsForm> createState() => _ProfileDetailsFormState();
}

class _ProfileDetailsFormState extends State<ProfileDetailsForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  @override
  void initState() {
    super.initState();

    _firstName.text = widget.account.firstName;
    _lastName.text = widget.account.lastName;
    _email.text = widget.account.email;
    _phone.text = widget.account.phoneNumber ?? '';
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _firstName,
      _lastName,
      _email,
      _phone,
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
          if (notifier.detailsFailureMessage
              case final String message) ...<Widget>[
            AppNotice(message),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: _firstName,
                  decoration: InputDecoration(
                    labelText: 'First name',
                    errorText: notifier.detailsMessageFor('firstName'),
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
                    errorText: notifier.detailsMessageFor('lastName'),
                  ),
                  validator: Validators.lastName,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _email,
            decoration: InputDecoration(
              labelText: 'Email',
              errorText: notifier.detailsMessageFor('email'),
            ),
            validator: Validators.emailAddress,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _phone,
            decoration: InputDecoration(
              labelText: 'Phone number',
              helperText: 'Optional, with a country code or as 061 234 567.',
              errorText: notifier.detailsMessageFor('phoneNumber'),
            ),
            validator: Validators.phoneNumber,
          ),
          const SizedBox(height: AppSpacing.xl),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: notifier.isWriting ? null : _submit,
              child: Text(notifier.isSavingDetails ? 'Saving' : 'Save changes'),
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

    final String typed = _phone.text.trim();

    final bool saved = await widget.notifier.saveDetails(
      UserDraft(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phoneNumber: typed.isEmpty ? null : typed,
      ),
    );

    if (saved && mounted) {
      widget.onSaved();
    }
  }
}
