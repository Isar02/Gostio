import 'package:intl/intl.dart';

// One place the client prints a figure. The product's money is BAM and the
// listing answers an amount without naming it, so the mark is written here.
abstract final class AppNumbers {
  static const String currency = 'KM';

  static String money(num value) => '${_amount.format(value)} $currency';

  static String rating(num value) => _rating.format(value);

  // What a figure looks like inside a field rather than in a column: no
  // grouping, no mark, and no trailing zero the typist did not put there.
  static String typed(num value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';

  static final NumberFormat _amount = NumberFormat('#,##0.00');
  static final NumberFormat _rating = NumberFormat('0.0');
}
