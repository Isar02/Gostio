import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// A filter nobody set is left out of the request rather than sent empty,
// which the API would read as a value to match.
@immutable
class UserQuery {
  const UserQuery({
    this.name,
    this.username,
    this.email,
    this.role,
    this.isActive,
  });

  // The API matches a name against either half and against the two together.
  final String? name;

  final String? username;
  final String? email;

  // The role's own name, which is what the API compares against.
  final String? role;

  final bool? isActive;

  bool get isEmpty => toParameters().isEmpty;

  JsonMap toParameters() => <String, dynamic>{
    'name': ?_written(name),
    'username': ?_written(username),
    'email': ?_written(email),
    'role': ?_written(role),
    'isActive': ?isActive,
  };

  @override
  bool operator ==(Object other) =>
      other is UserQuery &&
      other.name == name &&
      other.username == username &&
      other.email == email &&
      other.role == role &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(name, username, email, role, isActive);

  static String? _written(String? value) {
    final String? trimmed = value?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
