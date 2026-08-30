import 'dart:convert';

abstract final class Validators {
  static const int passwordMaximumBytes = 72;

  static String? username(String? value) =>
      _isBlank(value) ? 'Enter your username.' : null;

  static String? password(String? value) {
    if (_isBlank(value)) {
      return 'Enter your password.';
    }

    if (utf8.encode(value!).length > passwordMaximumBytes) {
      return 'A password is at most $passwordMaximumBytes bytes long once '
          'written as UTF-8.';
    }

    return null;
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;
}
