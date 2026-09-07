import 'package:gostio_core/gostio_core.dart';

// The four fields an account may write about itself. The username is not among
// them — it is written once, when the account is made — and the roles are an
// administrator's to change.
class ProfileDraft {
  const ProfileDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
  });

  // What the account holds now, which is what the form opens on.
  factory ProfileDraft.of(User account) => ProfileDraft(
    firstName: account.firstName,
    lastName: account.lastName,
    email: account.email,
    phoneNumber: account.phoneNumber,
  );

  final String firstName;
  final String lastName;
  final String email;

  // Sent even when it is null, because emptying the field is how a number is
  // taken off an account.
  final String? phoneNumber;

  bool hasSameFieldsAs(User account) =>
      firstName == account.firstName &&
      lastName == account.lastName &&
      email == account.email &&
      phoneNumber == account.phoneNumber;

  JsonMap toUpdate() => <String, dynamic>{
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phoneNumber': phoneNumber,
  };
}
