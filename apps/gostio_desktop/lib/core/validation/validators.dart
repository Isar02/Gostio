import 'dart:convert';

import '../formatting/app_numbers.dart';

abstract final class Validators {
  static const int passwordMaximumBytes = 72;

  // The lengths and bounds the server holds, mirrored so a value it would
  // refuse is refused here first and named the same way.
  static const int titleMaximum = 200;
  static const int descriptionMaximum = 2000;
  static const int addressMaximum = 250;
  static const int nameMaximum = 100;
  static const double smallestAmount = 0.01;
  static const double largestAmount = 1000000;

  // The server counts in 32 bits, and Dart's int reaches far past that.
  static const int largestWhole = 2147483647;

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

  static String? cityName(String? value) => _written(
    value,
    missing: 'Enter a name.',
    noun: 'A name',
    longest: nameMaximum,
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

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;
}
