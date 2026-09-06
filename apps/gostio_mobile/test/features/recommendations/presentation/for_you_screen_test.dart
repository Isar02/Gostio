import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/widgets/listing_card.dart';
import 'package:gostio_mobile/features/recommendations/presentation/for_you_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/listing_double.dart';
import '../../../support/phone.dart';
import '../../../support/recommendation_fixture.dart';
import '../../../support/recommendations_double.dart';
import '../../../support/screens.dart';

// What the server suggests, why each one is suggested, and the catalogue the
// ranking was made inside.
void main() {
  setUp(usePhoneScreen);

  Future<void> open(
    WidgetTester tester,
    RecommendationsDouble suggestions, {
    ListingDouble? listings,
  }) async {
    await tester.pumpWidget(
      underTest(
        const ForYouScreen(),
        auth: AuthDouble(),
        suggestions: suggestions,
        listings: listings,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, String catalogue) async {
    await tester.tap(find.text(catalogue));
    await tester.pumpAndSettle();
  }

  // The reasons are the screen. Everything else on the card is what Explore
  // already draws, and without them a suggestion is an unexplained listing.
  testWidgets('a suggestion carries the reasons the server read off it', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      RecommendationsDouble(
        stays: <Recommendation>[
          pick(
            reasons: <RecommendationReason>[
              because(RecommendationReasonKind.city, 'Mostar'),
              because(RecommendationReasonKind.amenity, 'Wi-Fi'),
              because(RecommendationReasonKind.price),
            ],
          ),
        ],
      ),
    );

    expect(find.text('In Mostar, where you have been looking'), findsOneWidget);
    expect(find.text('Has Wi-Fi, which you look for'), findsOneWidget);
    expect(find.text('Priced near what you usually pay'), findsOneWidget);
  });

  // A kind added to the server after this build shipped has no sentence here.
  // Saying nothing about it is right; inventing one around a value the client
  // cannot read is not.
  testWidgets('a reason this build cannot word is left unsaid', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      RecommendationsDouble(
        stays: <Recommendation>[
          pick(
            reasons: <RecommendationReason>[
              because(RecommendationReasonKind.unknown, 'Sunny'),
              because(RecommendationReasonKind.capacity),
            ],
          ),
        ],
      ),
    );

    expect(find.text('Room for the party you book for'), findsOneWidget);
    expect(find.textContaining('Sunny'), findsNothing);
  });

  // A detail the server left out of a kind that names one is not a sentence
  // with a hole in it.
  testWidgets('a reason with no value to name is left unsaid', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      RecommendationsDouble(
        stays: <Recommendation>[
          pick(
            reasons: <RecommendationReason>[
              because(RecommendationReasonKind.city),
              because(RecommendationReasonKind.rating, '4.8'),
            ],
          ),
        ],
      ),
    );

    expect(find.text('Rated 4.8, above average here'), findsOneWidget);
    expect(find.textContaining('where you have been looking'), findsNothing);
  });

  testWidgets('a numeric reason uses the shared figure format', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      RecommendationsDouble(
        stays: <Recommendation>[
          pick(
            reasons: <RecommendationReason>[
              because(RecommendationReasonKind.rating, '4.72'),
              because(RecommendationReasonKind.rating, 'not-a-rating'),
            ],
          ),
        ],
      ),
    );

    expect(find.text('Rated 4.7, above average here'), findsOneWidget);
    expect(find.textContaining('not-a-rating'), findsNothing);
  });

  testWidgets('one keeping is a time rather than one times', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      RecommendationsDouble(
        stays: <Recommendation>[
          pick(
            reasons: <RecommendationReason>[
              because(RecommendationReasonKind.popularity, '1'),
            ],
          ),
        ],
      ),
    );

    expect(find.text('Kept or booked 1 time'), findsOneWidget);
  });

  testWidgets('the two catalogues are two rankings asked for separately', (
    WidgetTester tester,
  ) async {
    final RecommendationsDouble suggestions = RecommendationsDouble(
      stays: picks(1, target: ListingKind.accommodation),
      terms: picks(2, target: ListingKind.experience),
    );
    await open(tester, suggestions);

    expect(find.text('Stay 1'), findsOneWidget);
    expect(find.text('per night'), findsOneWidget);

    await reveal(tester, 'Experiences');

    expect(find.text('Term 1'), findsOneWidget);
    expect(find.text('per person'), findsNWidgets(2));
    expect(find.text('Stay 1'), findsNothing);
    expect(suggestions.asked, <({ListingKind catalogue, int page})>[
      (catalogue: ListingKind.accommodation, page: 1),
      (catalogue: ListingKind.experience, page: 1),
    ]);
  });

  // A place scrolled to in one ranking is not a place in the other, and the
  // top of a ranking is the part of it worth reading.
  testWidgets('the other catalogue is read from the top of its ranking', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      RecommendationsDouble(
        stays: picks(6, target: ListingKind.accommodation),
        terms: picks(6, target: ListingKind.experience),
      ),
    );

    await tester.scrollUntilVisible(find.text('Stay 5'), 300);
    await reveal(tester, 'Experiences');

    expect(find.text('Term 1'), findsOneWidget);
  });

  testWidgets('a refused catalogue never leaves the other ranking under it', (
    WidgetTester tester,
  ) async {
    final Completer<PagedResult<Recommendation>> terms =
        Completer<PagedResult<Recommendation>>();
    await open(
      tester,
      RecommendationsDouble(
        stays: picks(1, target: ListingKind.accommodation),
        termsResponse: terms.future,
      ),
    );

    await tester.tap(find.text('Experiences'));
    await tester.pump();

    expect(find.text('Stay 1'), findsNothing);

    terms.completeError(
      const ApiException(message: 'The experience ranking could not be read.'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stay 1'), findsNothing);
    expect(
      find.text('The experience ranking could not be read.'),
      findsOneWidget,
    );
  });

  testWidgets('a suggestion opens the listing it stands for', (
    WidgetTester tester,
  ) async {
    final ListingDouble listings = ListingDouble();
    await open(
      tester,
      RecommendationsDouble(
        stays: <Recommendation>[
          pick(listingId: 7, target: ListingKind.experience),
        ],
      ),
      listings: listings,
    );

    await tester.tap(find.byType(ListingCard));
    await tester.pumpAndSettle();

    expect(listings.reads, <ListingAddress>[
      const ListingAddress(ListingKind.experience, 7),
    ]);
  });

  testWidgets('an account nothing can be read from is told what to do', (
    WidgetTester tester,
  ) async {
    await open(tester, RecommendationsDouble());

    expect(find.text('Nothing to suggest here yet'), findsOneWidget);
  });

  testWidgets('a refused ranking says so in the server words', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      RecommendationsDouble(
        failure: const ApiException(message: 'The API could not be reached.'),
      ),
    );

    expect(find.text('The API could not be reached.'), findsOneWidget);
  });
}
