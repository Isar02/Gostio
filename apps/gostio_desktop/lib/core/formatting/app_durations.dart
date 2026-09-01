// One place the client turns a length of time into words. The API holds
// minutes, and a reader holds hours.
abstract final class AppDurations {
  static const int _minutesInHour = 60;

  static String inWords(int minutes) {
    if (minutes < _minutesInHour) {
      return '$minutes min';
    }

    final int hours = minutes ~/ _minutesInHour;
    final int rest = minutes % _minutesInHour;

    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }
}
