import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/calendar/date_range.dart';
import 'package:gostio_mobile/features/booking/data/stay_quote.dart';

void main() {
  DateTime june(int day) => DateTime(2026, 6, day);

  final DateRange threeNights = DateRange(from: june(12), to: june(15));

  test('a stay is the nights it covers plus the fee charged once over it', () {
    final StayQuote? quote = StayQuote.of(
      threeNights,
      priceOf: (DateTime night) => 90,
      cleaningFee: 15,
    );

    expect(quote?.nights, 3);
    expect(quote?.nightsTotal, 270);
    expect(quote?.total, 285);
  });

  // The day a stay ends on belongs to the next guest, so pricing it would
  // charge for a night nobody bought.
  test('the day a stay ends on is not one of its nights', () {
    final List<DateTime> priced = <DateTime>[];

    StayQuote.of(
      threeNights,
      priceOf: (DateTime night) {
        priced.add(night);

        return 90;
      },
      cleaningFee: 0,
    );

    expect(priced, <DateTime>[june(12), june(13), june(14)]);
  });

  test('nights are added at what each of them costs', () {
    final StayQuote? quote = StayQuote.of(
      threeNights,
      priceOf: (DateTime night) => night == june(13) ? 140 : 90,
      cleaningFee: 0,
    );

    expect(quote?.total, 320);
  });

  // A total made out of the nights the client happens to hold is not the one
  // the server would charge, so the screen is offered none.
  test('a night the calendar has not priced leaves no quote at all', () {
    final StayQuote? quote = StayQuote.of(
      threeNights,
      priceOf: (DateTime night) => night == june(13) ? null : 90,
      cleaningFee: 15,
    );

    expect(quote, isNull);
  });
}
