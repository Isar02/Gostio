import '../../../core/models/user.dart';
import '../../../core/network/api_client.dart';

// The four fields both endpoints take. What only a new account carries — the
// username it is known by, the password it starts with, the roles it holds —
// is named where it is written: the username and password are never written
// again through this form, and the roles have an endpoint of their own.
class UserDraft {
  const UserDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
  });

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

  JsonMap toCreate({
    required String username,
    required String password,
    required String confirmPassword,
    required List<String> roles,
  }) => <String, dynamic>{
    ..._fields,
    'username': username,
    'password': password,
    'confirmPassword': confirmPassword,
    'roles': roles,
  };

  JsonMap toUpdate() => _fields;

  JsonMap get _fields => <String, dynamic>{
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phoneNumber': phoneNumber,
  };
}
