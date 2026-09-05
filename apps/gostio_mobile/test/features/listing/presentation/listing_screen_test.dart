import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/widgets/listing_map.dart';
import 'package:gostio_mobile/features/listing/data/listing_detail.dart';
import 'package:gostio_mobile/features/listing/presentation/favorite_edits.dart';
import 'package:gostio_mobile/features/listing/presentation/listing_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/listing_double.dart';
import '../../../support/listing_fixture.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

const ListingAddress _stay = ListingAddress(ListingKind.accommodation, 1);
const ListingAddress _term = ListingAddress(ListingKind.experience, 1);

void main() {
  setUp(usePhoneScreen);

  Future<void> open(
    WidgetTester tester,
    ListingDouble listings, {
    ListingAddress address = _stay,
    FavoriteEdits? favorites,
  }) async {
    await tester.pumpWidget(
      underTest(
        ListingScreen(address),
        auth: AuthDouble(),
        listings: listings,
        favorites: favorites,
      ),
    );
    await tester.pumpAndSettle();
  }

  // A section below the fold is a section no finder can see until it has been
  // scrolled to.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300);
    await tester.pumpAndSettle();
  }

  testWidgets('a stay is drawn from the row and the collections under it', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      ListingDouble(
        detail: StayDetail(stay(title: 'Old town loft', cityName: 'Sarajevo')),
        amenities: const <LookupItem>[
          LookupItem(id: 1, name: 'Wi-Fi'),
          LookupItem(id: 2, name: 'Free parking'),
        ],
      ),
    );

    expect(find.text('Old town loft'), findsNWidgets(2));
    expect(find.text('Sarajevo, Bosnia and Herzegovina'), findsOneWidget);
    expect(find.text('90.00 KM'), findsOneWidget);
    expect(find.text('per night'), findsOneWidget);
    expect(find.text('plus 15.00 KM cleaning fee'), findsOneWidget);
    expect(
      find.text('Apartment · City break · 4 guests · 2 bedrooms · 1 bathroom'),
      findsOneWidget,
    );
    expect(find.text('Hosted by Amir Hodžić'), findsOneWidget);

    await scrollTo(tester, find.text('Wi-Fi'));
    expect(find.text('Free parking'), findsOneWidget);
  });

  // A term is the same screen with what a term has instead of what a stay has:
  // no rooms, no amenities and no month of nights to take.
  testWidgets('a term is drawn without the collections only a stay has', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      ListingDouble(
        detail: ExperienceDetail(experience(title: 'Rafting the Neretva')),
      ),
      address: _term,
    );

    expect(find.text('25.00 KM'), findsOneWidget);
    expect(find.text('per person'), findsOneWidget);
    expect(find.text('Walking tour · 3 h'), findsOneWidget);
    expect(find.text('What this place offers'), findsNothing);
    expect(find.text('Availability'), findsNothing);
    expect(find.text('Where you meet'), findsOneWidget);
    expect(find.text('Sebilj'), findsOneWidget);
  });

  // The screen the coordinates exist for. The map on the page is a picture
  // rather than a map that is driven, because a map inside a page that scrolls
  // takes every drag that lands on it.
  testWidgets('the place is drawn on a map that opens a map', (
    WidgetTester tester,
  ) async {
    await open(tester, ListingDouble());

    await scrollTo(tester, find.byType(ListingMap));
    expect(find.text('Where you will be'), findsOneWidget);
    expect(find.text('Maršala Tita 14'), findsOneWidget);
    expect(find.text(mapCredit), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Open the map'));
    await tester.pumpAndSettle();

    expect(find.text('Map data'), findsOneWidget);
    expect(find.byType(ListingMap), findsOneWidget);
  });

  testWidgets('a listing that is still being read says so', (
    WidgetTester tester,
  ) async {
    final ListingDouble listings = ListingDouble(holdsTheCall: true);

    await tester.pumpWidget(
      underTest(
        const ListingScreen(_stay),
        auth: AuthDouble(),
        listings: listings,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    listings.answer();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a listing that could not be read is answered on its screen', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      ListingDouble(
        failure: ApiException(
          message: 'This listing is no longer on offer.',
          statusCode: 404,
          traceId: '00-9f2',
        ),
      ),
    );

    expect(find.text('This listing is no longer on offer.'), findsOneWidget);
    expect(find.text('Trace 00-9f2'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the gallery says which picture of how many is being read', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      ListingDouble(
        photos: <ListingPhoto>[
          listingPhoto(id: 1, isCover: true),
          listingPhoto(id: 2, displayOrder: 1),
          listingPhoto(id: 3, displayOrder: 2),
        ],
      ),
    );

    expect(find.text('1 of 3'), findsOneWidget);
  });

  testWidgets('a listing with no pictures is drawn without them', (
    WidgetTester tester,
  ) async {
    await open(tester, ListingDouble());

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('the heart is turned only once the server has taken it', (
    WidgetTester tester,
  ) async {
    final ListingDouble listings = ListingDouble();
    final FavoriteEdits edits = FavoriteEdits();

    await open(tester, listings, favorites: edits);

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(listings.saved, <ListingAddress>[_stay]);
    // The list this screen was opened from is still holding the row as it was
    // read, so what was written here is recorded where that list looks.
    expect(edits.of(_stay), isTrue);
  });

  testWidgets('a listing already saved is unsaved by the same heart', (
    WidgetTester tester,
  ) async {
    final ListingDouble listings = ListingDouble(
      detail: StayDetail(stay(isFavorite: true)),
    );
    final FavoriteEdits edits = FavoriteEdits();

    await open(tester, listings, favorites: edits);

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(listings.unsaved, <ListingAddress>[_stay]);
    expect(edits.of(_stay), isFalse);
  });

  // A heart that fills and empties again says the client was guessing.
  testWidgets('a refused heart stays as it was and says what happened', (
    WidgetTester tester,
  ) async {
    final FavoriteEdits edits = FavoriteEdits();

    await open(
      tester,
      ListingDouble(
        favoriteFailure: ApiException(
          message: 'That could not be saved just now.',
          statusCode: 500,
        ),
      ),
      favorites: edits,
    );

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.text('That could not be saved just now.'), findsOneWidget);
    expect(edits.of(_stay), isNull);
  });

  // What the reader has already done outranks the row, which the server wrote
  // before the heart was touched.
  testWidgets('a heart turned elsewhere outranks the row it was read in', (
    WidgetTester tester,
  ) async {
    final FavoriteEdits edits = FavoriteEdits()
      ..record(_stay, isFavorite: true);

    await open(tester, ListingDouble(), favorites: edits);

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });
}
