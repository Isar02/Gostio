import 'package:intl/intl.dart';

// One place the client prints a figure. The product's money is BAM and the
// listing answers an amount without naming it, so the mark is written here.
abstract final class AppNumbers {
  static const String currency = 'KM';

  static String money(num value) => '${_amount.format(value)} $currency';

  // A charge names the currency it was taken in, which is the mark unless the
  // processor was configured for another one.
  static String moneyIn(num value, String code) => code.toUpperCase() == _bam
      ? money(value)
      : '${_amount.format(value)} ${code.toUpperCase()}';

  static String rating(num value) => _rating.format(value);

  // What a figure looks like inside a field rather than in a column: no
  // grouping, no mark, and no trailing zero the typist did not put there.
  static String typed(num value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';

  static String size(int bytes) => switch (bytes) {
    < _kilobyte => '$bytes B',
    < _megabyte => '${_size.format(bytes / _kilobyte)} KB',
    _ => '${_size.format(bytes / _megabyte)} MB',
  };

  static const String _bam = 'BAM';

  static const int _kilobyte = 1024;
  static const int _megabyte = 1024 * 1024;

  static final NumberFormat _amount = NumberFormat('#,##0.00');
  static final NumberFormat _rating = NumberFormat('0.0');
  static final NumberFormat _size = NumberFormat('#,##0.#');
}
