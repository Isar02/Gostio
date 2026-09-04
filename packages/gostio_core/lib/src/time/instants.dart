// A moment on the wire. The value written is UTC, and the offset is left off:
// a binder reads one against the server's zone rather than the reader's.
abstract final class Instants {
  static String write(DateTime moment) {
    final DateTime utc = moment.toUtc();

    return '${_padded(utc.year, 4)}-${_padded(utc.month, 2)}-'
        '${_padded(utc.day, 2)}T${_padded(utc.hour, 2)}:'
        '${_padded(utc.minute, 2)}:${_padded(utc.second, 2)}.'
        '${_padded(utc.millisecond, 3)}${_padded(utc.microsecond, 3)}';
  }

  // The last instant the stored column can hold inside that day. The API
  // compares with <=, and the column counts in hundreds of nanoseconds — one
  // digit finer than Dart reaches, so that digit is written rather than
  // counted.
  static String endOfDay(DateTime day) => '${write(_lastMicrosecondOf(day))}9';

  static DateTime _lastMicrosecondOf(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day + 1,
  ).subtract(const Duration(microseconds: 1));

  static String _padded(int value, int width) =>
      value.toString().padLeft(width, '0');
}
