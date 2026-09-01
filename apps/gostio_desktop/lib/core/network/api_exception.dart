import 'package:flutter/foundation.dart';

@immutable
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.errors = const <String, List<String>>{},
    this.traceId,
  });

  factory ApiException.fromBody(int? statusCode, Map<String, dynamic> body) {
    final Object? message = body['message'];
    final Object? traceId = body['traceId'];

    return ApiException(
      message: message is String ? message : _unreadableMessage,
      statusCode: statusCode,
      errors: _readErrors(body['errors']),
      traceId: traceId is String ? traceId : null,
    );
  }

  static const String _unreadableMessage =
      'The API answered with a failure it did not describe.';

  final String message;
  final int? statusCode;
  final Map<String, List<String>> errors;
  final String? traceId;

  bool get isUnauthorized => statusCode == 401;

  bool get faultsAField => errors.isNotEmpty;

  // The API keys these by the property it bound, which is PascalCase, while a
  // caller naturally asks for the field it put in the request body.
  List<String> messagesFor(String field) {
    for (final MapEntry<String, List<String>> entry in errors.entries) {
      if (entry.key.toLowerCase() == field.toLowerCase()) {
        return entry.value;
      }
    }

    return const <String>[];
  }

  String? firstMessageFor(String field) {
    final List<String> messages = messagesFor(field);

    return messages.isEmpty ? null : messages.first;
  }

  static Map<String, List<String>> _readErrors(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return const <String, List<String>>{};
    }

    final Map<String, List<String>> errors = <String, List<String>>{};
    for (final MapEntry<String, dynamic> entry in raw.entries) {
      final Object? messages = entry.value;
      if (messages is List) {
        errors[entry.key] = messages.whereType<String>().toList(
          growable: false,
        );
      }
    }

    return errors;
  }

  @override
  String toString() => message;
}
