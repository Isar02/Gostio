import 'dart:convert';

import '../formatting/app_numbers.dart';

abstract final class Validators {
  // The server's own sentence for a number it will not take.
  static const String phoneNumberMeans =
      'Enter a phone number with its country code, as +387 61 234 567 or '
      '+49 170 1234567. A number without one is read as Bosnian: 061 234 567.';

  static const int passwordMinimumLength = 8;
  static const int passwordMaximumBytes = 72;

  // The lengths and bounds the server holds, mirrored so a value it would
  // refuse is refused here first and named the same way.
  static const int titleMaximum = 200;
  static const int descriptionMaximum = 2000;
  static const int newsBodyMaximum = 4000;
  static const int addressMaximum = 250;
  static const int nameMaximum = 100;
  static const int usernameMaximum = 50;
  static const int emailMaximum = 254;
  static const int phoneMaximum = 30;
  static const int codeMaximum = 30;
  static const int reasonMaximum = 1000;
  static const int messageBodyMaximum = 2000;
  static const double smallestAmount = 0.01;
  static const double largestAmount = 1000000;

  // The server counts in 32 bits, and Dart's int reaches far past that.
  static const int largestWhole = 2147483647;

  static String? username(String? value) =>
      _isBlank(value) ? 'Enter your username.' : null;

  static String? password(String? value) =>
      _password(value, missing: 'Enter your password.');

  static String? firstName(String? value) => _written(
    value,
    missing: 'Enter a first name.',
    noun: 'A first name',
    longest: nameMaximum,
  );

  static String? lastName(String? value) => _written(
    value,
    missing: 'Enter a last name.',
    noun: 'A last name',
    longest: nameMaximum,
  );

  static String? accountUsername(String? value) {
    final String? written = _written(
      value,
      missing: 'Enter a username.',
      noun: 'A username',
      longest: usernameMaximum,
    );

    if (written != null) {
      return written;
    }

    return _usernameShape.hasMatch(value!.trim())
        ? null
        : 'A username holds letters, digits, dots, dashes and underscores.';
  }

  static String? emailAddress(String? value) {
    final String? written = _written(
      value,
      missing: 'Enter an email address.',
      noun: 'An email address',
      longest: emailMaximum,
    );

    return written ??
        (_emailShape.hasMatch(value!.trim())
            ? null
            : 'This is not an email address.');
  }

  // A number is optional, and one that is typed is read the way the server
  // reads it: separators mean nothing, and a local number is Bosnian.
  static String? phoneNumber(String? value) {
    if (_isBlank(value)) {
      return null;
    }

    final String typed = value!.trim();

    if (typed.length > phoneMaximum) {
      return 'A phone number is at most $phoneMaximum characters long.';
    }

    return _dialled(typed) == null ? phoneNumberMeans : null;
  }

  // The minimum length is deliberately not applied: the password an account
  // already has was taken under a policy that may since have moved, and holding
  // it to today's would refuse one the server is about to accept. The ceiling
  // is applied, because the server holds this field to it as well.
  static String? currentPassword(String? value) =>
      _password(value, missing: 'Enter your current password.');

  static String? newPassword(String? value, {required String missing}) {
    if (_isBlank(value)) {
      return missing;
    }

    if (value!.length < passwordMinimumLength) {
      return 'A password is at least $passwordMinimumLength characters long.';
    }

    return utf8.encode(value).length > passwordMaximumBytes
        ? 'A password is at most $passwordMaximumBytes bytes long once '
              'written as UTF-8.'
        : null;
  }

  static String? repeatedPassword(
    String? value,
    String password, {
    required String missing,
  }) {
    if (_isBlank(value)) {
      return missing;
    }

    return value == password ? null : 'The two passwords do not match.';
  }

  static String? rejectionReason(String? value) => _written(
    value,
    missing: 'Say why the request is being turned down.',
    noun: 'A reason',
    longest: reasonMaximum,
  );

  // A reason an approval may go without, and only its length is checked.
  static String? decisionNote(String? value) =>
      _isBlank(value) || value!.trim().length <= reasonMaximum
      ? null
      : 'A reason is at most $reasonMaximum characters long.';

  static String? title(String? value) => _written(
    value,
    missing: 'Enter a title.',
    noun: 'A title',
    longest: titleMaximum,
  );

  static String? description(String? value) => _written(
    value,
    missing: 'Enter a description.',
    noun: 'A description',
    longest: descriptionMaximum,
  );

  static String? newsBody(String? value) => _written(
    value,
    missing: 'Enter the text.',
    noun: 'A text',
    longest: newsBodyMaximum,
  );

  static String? messageBody(String? value) => _written(
    value,
    missing: 'A message needs something in it.',
    noun: 'A message',
    longest: messageBodyMaximum,
  );

  static String? address(String? value) => _written(
    value,
    missing: 'Enter an address.',
    noun: 'An address',
    longest: addressMaximum,
  );

  static String? meetingPoint(String? value) => _written(
    value,
    missing: 'Enter a meeting point.',
    noun: 'A meeting point',
    longest: addressMaximum,
  );

  static String? lookupName(String? value) => _written(
    value,
    missing: 'Enter a name.',
    noun: 'A name',
    longest: nameMaximum,
  );

  static String? countryCode(String? value) {
    if (_isBlank(value)) {
      return 'Enter the two letter country code.';
    }

    return _countryCodeShape.hasMatch(value!.trim())
        ? null
        : 'A country code is two letters.';
  }

  static String? code(String? value) => _written(
    value,
    missing: 'Enter a code.',
    noun: 'A code',
    longest: codeMaximum,
  );

  // A description a reference row may go without, and only its length is
  // checked.
  static String? optionalDescription(String? value) =>
      _isBlank(value) || value!.trim().length <= descriptionMaximum
      ? null
      : 'A description is at most $descriptionMaximum characters long.';

  static String? cancellationReason(String? value) => _written(
    value,
    missing: 'Say why the reservation is being cancelled.',
    noun: 'A reason',
    longest: reasonMaximum,
  );

  static String? guests(String? value) => _counted(
    value,
    outside: 'An accommodation takes at least one guest.',
    smallest: 1,
  );

  static String? capacity(String? value) => _counted(
    value,
    outside: 'A slot takes at least one person.',
    smallest: 1,
  );

  static String? duration(String? value) => _counted(
    value,
    outside: 'An experience lasts at least a minute.',
    smallest: 1,
  );

  static String? bedrooms(String? value) =>
      _counted(value, outside: 'A bedroom count is zero or more.');

  static String? bathrooms(String? value) =>
      _counted(value, outside: 'A bathroom count is zero or more.');

  static String? price(String? value) =>
      _amount(value, noun: 'A nightly price', smallest: smallestAmount);

  static String? fee(String? value) => _amount(value, noun: 'A cleaning fee');

  static String? pricePerPerson(String? value) =>
      _amount(value, noun: 'A price per person', smallest: smallestAmount);

  // A password that is only being proved, not set: what is typed has to reach
  // the server as it stands, so only the ceiling BCrypt and the server share
  // is checked here.
  static String? _password(String? value, {required String missing}) {
    if (_isBlank(value)) {
      return missing;
    }

    return utf8.encode(value!).length > passwordMaximumBytes
        ? 'A password is at most $passwordMaximumBytes bytes long once '
              'written as UTF-8.'
        : null;
  }

  static String? _written(
    String? value, {
    required String missing,
    required String noun,
    required int longest,
  }) {
    if (_isBlank(value)) {
      return missing;
    }

    return value!.trim().length > longest
        ? '$noun is at most $longest characters long.'
        : null;
  }

  // The message is the server's own, word for word, so the two never say the
  // same refusal differently. Its upper bound has no message of its own — a
  // value that large never binds there — so this one names the ceiling.
  static String? _counted(
    String? value, {
    required String outside,
    int smallest = 0,
  }) {
    final int? counted = int.tryParse(value?.trim() ?? '');

    if (counted == null || counted < smallest) {
      return outside;
    }

    return counted > largestWhole
        ? 'That is more than the $largestWhole this counts up to.'
        : null;
  }

  static String? _amount(
    String? value, {
    required String noun,
    double smallest = 0,
  }) {
    final double? amount = double.tryParse(value?.trim() ?? '');

    if (amount == null) {
      return '$noun is a figure, with at most two decimals.';
    }

    if (amount < smallest || amount > largestAmount) {
      return '$noun is between ${AppNumbers.typed(smallest)} and '
          '${AppNumbers.typed(largestAmount)}.';
    }

    return null;
  }

  // The stored form of a number, or null when it is not one. Separators carry
  // no meaning, and a nine-digit local number is dialled in Bosnia.
  static String? _dialled(String number) {
    final String stripped = number.replaceAll(_separators, '');
    final String international = _localNumber.hasMatch(stripped)
        ? '$_bosniaCode${stripped.substring(1)}'
        : stripped;

    return _internationalNumber.hasMatch(international) ? international : null;
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  static const String _bosniaCode = '+387';

  static final RegExp _usernameShape = RegExp(r'^[A-Za-z0-9._-]+$');
  static final RegExp _countryCodeShape = RegExp(r'^[A-Za-z]{2}$');
  static final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _separators = RegExp(r'[\s\-()]');
  static final RegExp _localNumber = RegExp(r'^0\d{8}$');
  static final RegExp _internationalNumber = RegExp(r'^\+[1-9]\d{7,14}$');
}
