import 'package:gostio_core/gostio_core.dart';

// The three fields a password change is made of. Unlike `ProfileDraft` this one
// opens on nothing and is compared with nothing: a password is written once and
// never read back, so there is no account state for it to differ from.
class PasswordDraft {
  const PasswordDraft({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmNewPassword,
  });

  final String currentPassword;
  final String newPassword;
  final String confirmNewPassword;

  JsonMap toChange() => <String, dynamic>{
    'currentPassword': currentPassword,
    'newPassword': newPassword,
    'confirmNewPassword': confirmNewPassword,
  };
}
