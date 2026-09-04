// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthResult _$AuthResultFromJson(Map<String, dynamic> json) => AuthResult(
  token: json['token'] as String,
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  user: User.fromJson(json['user'] as Map<String, dynamic>),
);
