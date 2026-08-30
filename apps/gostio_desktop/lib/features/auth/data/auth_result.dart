import 'package:json_annotation/json_annotation.dart';

import '../../../core/models/user.dart';

part 'auth_result.g.dart';

@JsonSerializable(createToJson: false)
class AuthResult {
  const AuthResult({
    required this.token,
    required this.expiresAt,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) =>
      _$AuthResultFromJson(json);

  final String token;
  final DateTime expiresAt;
  final User user;
}
