import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

// A row that says when something happened may not stop at the day it happened
// on. Inside the day the relative form says the time better than a clock does;
// past that it is the moment itself, hour included.
void main() {
  DateTime ago(Duration age) => DateTime.now().toUtc().subtract(age);

  test('a moment inside the hour is read against now', () {
    expect(AppDates.age(ago(const Duration(seconds: 20))), 'Just now');
    expect(AppDates.age(ago(const Duration(minutes: 12))), '12 min ago');
  });

  test('a moment inside the day is read in hours', () {
    expect(AppDates.age(ago(const Duration(hours: 3))), '3 h ago');
  });

  // Where the relative form stops being precise, the stamp takes over — and it
  // carries the hour rather than the day alone.
  test('a moment older than a day carries its date and its time', () {
    final DateTime older = ago(const Duration(days: 3));

    expect(AppDates.age(older), AppDates.dateTime(older));
    expect(AppDates.age(older), isNot(AppDates.date(older)));
    expect(AppDates.age(older), contains(':'));
  });

  test('the two stamps say what they are named for', () {
    final DateTime moment = DateTime.utc(2026, 9, 7, 14, 30);

    expect(AppDates.date(moment), isNot(contains(':')));
    expect(AppDates.dateTime(moment), contains(':'));
  });
}
