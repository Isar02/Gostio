import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/widgets/listing_card.dart';
import 'package:gostio_mobile/features/favorites/presentation/favorites_screen.dart';
import 'package:gostio_mobile/features/listing/presentation/favorite_edits.dart';

import '../../../support/auth_double.dart';
import '../../../support/favorite_fixture.dart';
import '../../../support/favorites_double.dart';
import '../../../support/listing_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

// What this account has kept, reached from the profile: both catalogues in one
// list, the listing each row leads to, and the row a listing left.
void main() {
  setUp(usePhoneScreen);

  Future<void> open(
    WidgetTester tester,
    FavoritesDouble saved, {
    FavoriteEdits? edits,
    ListingDouble? listings,
  }) => pushOnto(
    tester,
    const FavoritesScreen(),
    auth: AuthDouble(),
    saved: saved,
    favorites: edits,
    listings: listings,
  );

  testWidgets('the list holds both catalogues and says how much of the whole', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      FavoritesDouble(
        kept: <Favorite>[
          favorite(listingTitle: 'Cottage by the Pliva lakes'),
          favorite(
            id: 2,
            accommodationId: null,
            experienceId: 9,
            listingTitle: 'Rafting the Neretva canyon',
            price: 75,
          ),
        ],
      ),
    );

    expect(find.byType(ListingCard), findsNWidgets(2));
    expect(find.text('per night'), findsOneWidget);
    expect(find.text('per person'), findsOneWidget);
    expect(find.text('Stay'), findsOneWidget);
    expect(find.text('Experience'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('2 of 2 saved'), 200);

    expect(find.text('2 of 2 saved'), findsOneWidget);
  });

  testWidgets('an account that has kept nothing is told what keeps one', (
    WidgetTester tester,
  ) async {
    await open(tester, FavoritesDouble());

    expect(find.text('You have not saved anything yet'), findsOneWidget);
  });

  // A withdrawn listing answers a guest 404, so the row says it has gone and
  // stops being a way in rather than opening a screen that cannot be read.
  testWidgets('a withdrawn listing stays saved and opens nothing', (
    WidgetTester tester,
  ) async {
    final ListingDouble listings = ListingDouble();
    await open(
      tester,
      FavoritesDouble(kept: <Favorite>[favorite(isListingActive: false)]),
      listings: listings,
    );

    expect(find.text('No longer listed'), findsOneWidget);

    await tester.tap(find.byType(ListingCard));
    await tester.pumpAndSettle();

    expect(listings.reads, isEmpty);
  });

  testWidgets('a row opens the listing it was saved from', (
    WidgetTester tester,
  ) async {
    final ListingDouble listings = ListingDouble();
    await open(
      tester,
      FavoritesDouble(kept: <Favorite>[favorite(accommodationId: 4)]),
      listings: listings,
    );

    await tester.tap(find.byType(ListingCard));
    await tester.pumpAndSettle();

    expect(listings.reads, <ListingAddress>[
      const ListingAddress(ListingKind.accommodation, 4),
    ]);
  });

  // The heart is turned on the listing's own screen. What it wrote comes back
  // here rather than sending a list several pages deep back to its first page.
  testWidgets('a listing unsaved elsewhere leaves the list and the count', (
    WidgetTester tester,
  ) async {
    final FavoriteEdits edits = FavoriteEdits();
    final FavoritesDouble saved = FavoritesDouble(
      kept: <Favorite>[
        favorite(accommodationId: 4),
        favorite(id: 2, accommodationId: 5, listingTitle: 'Attic in Bihać'),
      ],
    );
    await open(tester, saved, edits: edits);

    edits.record(
      const ListingAddress(ListingKind.accommodation, 4),
      isFavorite: false,
    );
    await tester.pumpAndSettle();

    expect(saved.pagesAsked, <int>[1]);
    expect(find.byType(ListingCard), findsOneWidget);
    expect(find.text('1 of 1 saved'), findsOneWidget);
  });

  // A listing saved somewhere else belongs where the server puts it in the
  // order, so nothing is inserted here and a pull is what asks for it.
  testWidgets('a listing saved elsewhere is not put into the list', (
    WidgetTester tester,
  ) async {
    final FavoriteEdits edits = FavoriteEdits();
    await open(
      tester,
      FavoritesDouble(kept: <Favorite>[favorite()]),
      edits: edits,
    );

    edits.record(
      const ListingAddress(ListingKind.accommodation, 99),
      isFavorite: true,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListingCard), findsOneWidget);
  });
}
