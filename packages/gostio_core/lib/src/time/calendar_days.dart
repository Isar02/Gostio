// A calendar day is a date rather than a moment. The API answers one as
// yyyy-MM-dd, which parses to local midnight, and the arithmetic here goes
// through the constructor rather than through Duration: a day is 23 or 25
// hours long where the clocks change, and adding 24 of them drifts.
abstract final class CalendarDays {
  static DateTime today() => of(DateTime.now());

  static DateTime of(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  static DateTime firstOfMonth(DateTime day) => DateTime(day.year, day.month);

  static DateTime addMonths(DateTime day, int months) =>
      DateTime(day.year, day.month + months);

  // The Monday on or before the day, which is where a week is drawn from.
  static DateTime startOfWeek(DateTime day) =>
      addDays(day, DateTime.monday - day.weekday);

  static int daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  // The form the API binds a date from.
  static String write(DateTime day) =>
      '${_padded(day.year, 4)}-${_padded(day.month, 2)}-${_padded(day.day, 2)}';

  static String _padded(int value, int width) =>
      value.toString().padLeft(width, '0');
}
