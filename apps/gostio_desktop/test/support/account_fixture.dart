import 'package:gostio_desktop/core/models/user.dart';

// An account the way the API answers one. What a test is actually about it
// names itself; everything else is a plausible row from the seed.
User account({
  int id = 7,
  String firstName = 'Lamija',
  String lastName = 'Hodžić',
  String username = 'lamija.h',
  String email = 'lamija.h@gostio.test',
  String? phoneNumber = '+38761234567',
  bool hasProfileImage = false,
  bool isActive = true,
  List<String> roles = const <String>['Host'],
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
  createdAt: DateTime.utc(2026, 3, 12, 9),
);
