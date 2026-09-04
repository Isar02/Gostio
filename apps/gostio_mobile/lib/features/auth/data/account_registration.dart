import 'package:gostio_core/gostio_core.dart';

// What a person opening an account fills in. An administrator creating one
// sends roles beside these; a registration is always a guest.
class AccountRegistration {
  const AccountRegistration({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.confirmPassword,
  });

  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String? phoneNumber;
  final String password;
  final String confirmPassword;

  JsonMap toJson() => <String, dynamic>{
    'firstName': firstName,
    'lastName': lastName,
    'username': username,
    'email': email,
    'phoneNumber': phoneNumber,
    'password': password,
    'confirmPassword': confirmPassword,
  };
}
