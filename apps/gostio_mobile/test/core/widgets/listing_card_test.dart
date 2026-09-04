import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/widgets/api_image.dart';
import 'package:gostio_mobile/core/widgets/listing_card.dart';
import 'package:gostio_mobile/core/widgets/status_chip.dart';

import '../../support/widgets.dart';

void main() {
  testWidgets('a card carries what a reader chooses between', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _card(
        title: 'Old town loft with a Baščaršija view',
        place: 'Sarajevo',
        price: 120,
        priceUnit: 'per night',
        rating: 4.8,
        reviewCount: 23,
      ),
    );

    expect(find.text('Old town loft with a Baščaršija view'), findsOneWidget);
    expect(find.text('Sarajevo'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('120.00 KM'), findsOneWidget);
    expect(find.text('per night'), findsOneWidget);
  });

  // The API answers a cover as an address, so the card is laid out to be
  // right before the picture arrives rather than after.
  testWidgets('a listing with no cover is still a whole card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _card(title: 'Cottage by the Pliva lakes', place: 'Jajce', price: 95),
    );

    expect(find.byType(ApiImage), findsOneWidget);
    expect(find.text('Cottage by the Pliva lakes'), findsOneWidget);
    expect(find.text('No reviews yet'), findsOneWidget);
  });

  testWidgets('a card opens the listing it stands for', (
    WidgetTester tester,
  ) async {
    int opened = 0;

    await tester.pumpWidget(
      _card(
        title: 'Rafting the Neretva canyon',
        place: 'Konjic',
        price: 65,
        priceUnit: 'per person',
        onTap: () => opened++,
      ),
    );

    await tester.tap(find.byType(ListingCard));
    await tester.pump();

    expect(opened, 1);
  });

  testWidgets('a status is drawn over the cover where one is given', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _card(
        title: 'Stone villa on the hill above Neum',
        place: 'Neum',
        price: 320,
        status: 'Confirmed',
        statusTone: Tone.positive,
      ),
    );

    expect(find.byType(StatusChip), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('a card with no status draws none', (WidgetTester tester) async {
    await tester.pumpWidget(
      _card(title: 'The Una by kayak at sunrise', place: 'Bihać', price: 80),
    );

    expect(find.byType(StatusChip), findsNothing);
  });

  // Four fragments read one after another are not a listing; this is the card
  // said once.
  testWidgets('a card is announced as one thing rather than as its pieces', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _card(
        title: 'Apartment above the Neretva in Konjic',
        place: 'Konjic',
        price: 140,
        priceUnit: 'per night',
        rating: 4.5,
        reviewCount: 12,
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Apartment above the Neretva in Konjic, Konjic, '
        'rated 4.5 from 12 reviews, 140.00 KM per night',
      ),
      findsOneWidget,
    );

    semantics.dispose();
  });

  // A count nobody supplied is unknown, and reading out a figure that is not
  // there is worse than leaving it unsaid.
  testWidgets('a rating with no count behind it is announced without one', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _card(
        title: 'Pliva waterfall and mill hike',
        place: 'Jajce',
        price: 55,
        rating: 4.6,
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Pliva waterfall and mill hike, Jajce, rated 4.6, 55.00 KM',
      ),
      findsOneWidget,
    );

    semantics.dispose();
  });

  testWidgets('one review is a review rather than one reviews', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _card(
        title: 'Kravice falls and Herzegovina wine',
        place: 'Ljubuski',
        price: 70,
        rating: 5,
        reviewCount: 1,
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Kravice falls and Herzegovina wine, Ljubuski, '
        'rated 5.0 from 1 review, 70.00 KM',
      ),
      findsOneWidget,
    );

    semantics.dispose();
  });
}

// A card is read inside a list, which is the only place its height is its
// own. Drawn into a box the size of the screen it would be squeezed, and
// nothing in the client ever draws one that way.
Widget _card({
  required String title,
  required String place,
  required double price,
  String? priceUnit,
  double? rating,
  int? reviewCount,
  String? status,
  Tone statusTone = Tone.neutral,
  VoidCallback? onTap,
}) => drawn(
  ListView(
    children: <Widget>[
      ListingCard(
        title: title,
        place: place,
        price: price,
        priceUnit: priceUnit,
        rating: rating,
        reviewCount: reviewCount,
        status: status,
        statusTone: statusTone,
        onTap: onTap,
      ),
    ],
  ),
);
