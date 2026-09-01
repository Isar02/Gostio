import 'package:intl/intl.dart';

// One place the client formats a moment. The API answers in UTC, so every
// format converts before it prints.
abstract final class AppDates {
  static final DateFormat _date = DateFormat('d MMM y');
  static final DateFormat _dateTime = DateFormat('d MMM y, HH:mm');
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _month = DateFormat('MMMM y');
  static final DateFormat _weekday = DateFormat('EEE');

  static String date(DateTime value) => _date.format(value.toLocal());

  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());

  static String time(DateTime value) => _time.format(value.toLocal());

  // A calendar day is the date it names rather than a moment somewhere else,
  // so these three print it where the two above convert first.
  static String day(DateTime value) => _date.format(value);

  static String month(DateTime value) => _month.format(value);

  static String weekday(DateTime value) => _weekday.format(value);

  // Read against now rather than printed as a date the reader has to subtract.
  static String age(DateTime value) {
    final Duration age = DateTime.now().difference(value.toLocal());

    return switch (age) {
      _ when age.inMinutes < 1 => 'Just now',
      _ when age.inHours < 1 => '${age.inMinutes} min ago',
      _ when age.inDays < 1 => '${age.inHours} h ago',
      _ when age.inDays < 7 => '${age.inDays} d ago',
      _ => date(value),
    };
  }
}
