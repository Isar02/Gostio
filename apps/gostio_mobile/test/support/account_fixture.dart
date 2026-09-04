import 'package:gostio_core/gostio_core.dart';

// An account the way the API answers one. What a test is actually about it
// names itself; everything else is a plausible row from the seed.
User account({
  int id = 12,
  String firstName = 'Emina',
  String lastName = 'Begić',
  String username = 'emina.b',
  String email = 'emina.b@gostio.test',
  String? phoneNumber = '+38761234567',
  bool hasProfileImage = false,
  bool isActive = true,
  List<String> roles = const <String>['Guest'],
}) => User(
  id: id,
  firstName: firstName,
  lastName: lastName,
  username: username,
  email: email,
  phoneNumber: phoneNumber,
  hasProfileImage: hasProfileImage,
  isActive: isActive,
  roles: roles,
  createdAt: DateTime.utc(2026, 5, 4, 11),
);

AuthResult issuedTo(User user, {String token = 'the-token'}) => AuthResult(
  token: token,
  expiresAt: DateTime.utc(2026, 5, 5, 11),
  user: user,
);
