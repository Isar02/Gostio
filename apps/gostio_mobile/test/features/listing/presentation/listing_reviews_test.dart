import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/listing/data/listing_detail.dart';
import 'package:gostio_mobile/features/listing/presentation/listing_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/listing_double.dart';
import '../../../support/listing_fixture.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

const ListingAddress _stay = ListingAddress(ListingKind.accommodation, 1);

void main() {
  setUp(usePhoneScreen);

  Future<void> open(
    WidgetTester tester,
    ListingDouble listings, {
    ListingAddress address = _stay,
  }) async {
    await tester.pumpWidget(
      underTest(ListingScreen(address), auth: AuthDouble(), listings: listings),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300);
    await tester.pumpAndSettle();
  }

  // A page of reviews inside a page that already scrolls is two lists fighting
  // over one gesture, so the listing shows the top of them and the rest is a
  // screen of its own.
  testWidgets('the listing shows the first reviews and the count of the rest', (
    WidgetTester tester,
  ) async {
    await open(tester, ListingDouble(reviewRows: reviews(5)));

    await scrollTo(tester, find.text('Reviews'));

    expect(find.text('Review 1'), findsOneWidget);
    expect(find.text('Review 3'), findsOneWidget);
    expect(find.text('Review 4'), findsNothing);
    expect(find.text('See all 5'), findsOneWidget);
  });

  testWidgets('the reviews behind them are the ones already read', (
    WidgetTester tester,
  ) async {
    final ListingDouble listings = ListingDouble(reviewRows: reviews(5));

    await open(tester, listings);
    await scrollTo(tester, find.text('See all 5'));
    await tester.tap(find.text('See all 5'));
    await tester.pumpAndSettle();

    expect(find.text('5 of 5 reviews'), findsOneWidget);
    await scrollTo(tester, find.text('Review 5'));

    // The screen borrowed the list the detail had already read rather than
    // asking the server for the same page a second time.
    expect(listings.reviewPagesAsked, <int>[1]);
  });

  testWidgets('a listing that has three reviews offers no screen of them', (
    WidgetTester tester,
  ) async {
    await open(tester, ListingDouble(reviewRows: reviews(3)));

    await scrollTo(tester, find.text('Reviews'));

    expect(find.text('Review 3'), findsOneWidget);
    expect(find.textContaining('See all'), findsNothing);
  });

  testWidgets('a listing nobody has written about says so', (
    WidgetTester tester,
  ) async {
    await open(tester, ListingDouble());

    await scrollTo(tester, find.text('No reviews yet'));

    expect(
      find.text('A review is written after a stay has been paid for.'),
      findsOneWidget,
    );
  });

  // A review is left against a booking that was paid for, and the two
  // catalogues are not booked in the same words.
  testWidgets('a term nobody has written about is not called a stay', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      ListingDouble(detail: ExperienceDetail(experience())),
      address: const ListingAddress(ListingKind.experience, 1),
    );

    await scrollTo(tester, find.text('No reviews yet'));

    expect(
      find.text('A review is written after an experience has been paid for.'),
      findsOneWidget,
    );
  });
}
