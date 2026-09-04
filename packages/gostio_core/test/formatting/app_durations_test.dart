import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

void main() {
  test('under an hour is read in minutes', () {
    expect(AppDurations.inWords(45), '45 min');
    expect(AppDurations.inWords(59), '59 min');
  });

  test('a whole number of hours drops the minutes', () {
    expect(AppDurations.inWords(60), '1 h');
    expect(AppDurations.inWords(240), '4 h');
  });

  test('anything else is read as both', () {
    expect(AppDurations.inWords(90), '1 h 30 min');
    expect(AppDurations.inWords(255), '4 h 15 min');
  });
}
