import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

void main() {
  test('a night is read as the day it names rather than a moment', () {
    final StayCalendarDay night = StayCalendarDay.fromJson(
      const <String, dynamic>{
        'date': '2026-09-15',
        'isBookable': true,
        'price': 120.5,
      },
    );

    expect(night.date, DateTime(2026, 9, 15));
    expect(night.isBookable, isTrue);
    expect(night.price, 120.5);
  });

  test('a night nobody may book is still answered', () {
    final StayCalendarDay night = StayCalendarDay.fromJson(
      const <String, dynamic>{
        'date': '2026-09-16',
        'isBookable': false,
        'price': 90,
      },
    );

    expect(night.isBookable, isFalse);
    expect(night.price, 90);
  });
}
