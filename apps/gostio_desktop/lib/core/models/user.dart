import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable(createToJson: false)
class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.hasProfileImage,
    required this.isActive,
    required this.roles,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String? phoneNumber;
  final bool hasProfileImage;
  final bool isActive;
  final List<String> roles;
  final DateTime createdAt;

  String get fullName => '$firstName $lastName';

  bool hasRole(String role) => roles.contains(role);
}
