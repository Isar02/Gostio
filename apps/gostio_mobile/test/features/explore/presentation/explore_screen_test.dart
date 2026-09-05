import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/widgets/listing_card.dart';
import 'package:gostio_mobile/features/explore/data/experience_filters.dart';
import 'package:gostio_mobile/features/explore/data/stay_filters.dart';
import 'package:gostio_mobile/features/explore/presentation/explore_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/catalogue_double.dart';
import '../../../support/listing_fixture.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<CatalogueDouble> openExplore(
    WidgetTester tester, {
    CatalogueDouble? catalogue,
    FilterOptionsDouble? filterOptions,
  }) async {
    final CatalogueDouble double = catalogue ?? CatalogueDouble();

    await tester.pumpWidget(
      underTest(
        // The bar over this is the shell's, so what a test draws is the body
        // the shell puts under it.
        const Scaffold(body: SafeArea(child: ExploreScreen())),
        auth: AuthDouble(),
        catalogue: double,
        filterOptions: filterOptions ?? FilterOptionsDouble(),
      ),
    );
    await tester.pumpAndSettle();

    return double;
  }

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
  }

  // The groups below the fold are reached the way a thumb reaches them.
  Future<void> choose(WidgetTester tester, String label) async {
    await tester.dragUntilVisible(
      find.text(label),
      find.byType(SingleChildScrollView).first,
      const Offset(0, -120),
    );
    await tester.tap(find.text(label));
    await tester.pump();
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();
  }

  testWidgets('the client opens on the stays that are on offer', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = await openExplore(
      tester,
      catalogue: CatalogueDouble(
        stays: <Accommodation>[stay(title: 'Loft over the river')],
      ),
    );

    expect(find.text('Loft over the river'), findsOneWidget);
    expect(catalogue.lastStayFilters, const StayFilters());
    expect(catalogue.lastStayFilters.toParameters()['isActive'], true);
  });

  // Two catalogues on one screen are two searches, and the one nobody has
  // looked at is not one of them.
  testWidgets('the catalogue behind the toggle is not read until it is shown', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = await openExplore(tester);

    expect(catalogue.experienceFilters, isEmpty);

    await tester.tap(find.text('Experiences'));
    await tester.pumpAndSettle();

    expect(catalogue.experienceFilters, hasLength(1));
  });

  testWidgets('a catalogue already read is not read again on coming back', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = await openExplore(tester);

    await tester.tap(find.text('Experiences'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stays'));
    await tester.pumpAndSettle();

    expect(catalogue.stayFilters, hasLength(1));
  });

  // The server keeps a row for every first page of a search, so a reader who
  // types six letters made one search rather than six.
  testWidgets('the words typed are searched on submitting, not on typing', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = await openExplore(tester);

    await tester.enterText(find.byType(TextField), 'loft');
    await tester.pump();

    expect(catalogue.stayFilters, hasLength(1));

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(catalogue.lastStayFilters.title, 'loft');
  });

  // A first page still on its way is not a reason to lose the search a reader
  // made while they waited for it.
  testWidgets('words submitted while the first page is still coming are kept', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = CatalogueDouble(holdsTheCall: true);

    await tester.pumpWidget(
      underTest(
        const Scaffold(body: SafeArea(child: ExploreScreen())),
        auth: AuthDouble(),
        catalogue: catalogue,
        filterOptions: FilterOptionsDouble(),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'loft');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    catalogue.answer();
    await tester.pumpAndSettle();

    expect(catalogue.lastStayFilters.title, 'loft');
  });

  testWidgets('the words in the field are carried across the toggle', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = await openExplore(tester);

    await tester.enterText(find.byType(TextField), 'walk');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Experiences'));
    await tester.pumpAndSettle();

    expect(catalogue.lastExperienceFilters.title, 'walk');
  });

  testWidgets('a filter chosen in the sheet is sent and shown as a chip', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = await openExplore(tester);

    await openFilters(tester);
    await choose(tester, 'Mostar');
    await apply(tester);

    expect(catalogue.lastStayFilters.city?.name, 'Mostar');
    expect(find.text('Filters (1)'), findsOneWidget);
    expect(find.text('Mostar'), findsOneWidget);
  });

  testWidgets('nothing is searched for until the sheet is closed on it', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = await openExplore(tester);

    await openFilters(tester);
    await choose(tester, 'Mostar');
    await choose(tester, 'House');

    expect(catalogue.stayFilters, hasLength(1));
  });

  testWidgets('a chip taken off searches again without that filter', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = await openExplore(tester);

    await openFilters(tester);
    await choose(tester, 'Mostar');
    await apply(tester);

    await tester.tap(find.text('Mostar'));
    await tester.pumpAndSettle();

    expect(catalogue.lastStayFilters, const StayFilters());
    expect(find.text('Filters'), findsOneWidget);
  });

  // The sheet is the surface that holds the draft, so it is the surface that
  // asks. Leaving it any other way than on its button loses what was chosen.
  testWidgets('leaving the sheet with something chosen asks first', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = await openExplore(tester);

    await openFilters(tester);
    await choose(tester, 'Mostar');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Leave these filters?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('Show results'), findsOneWidget);
    expect(catalogue.stayFilters, hasLength(1));
  });

  testWidgets('a sheet nobody changed closes without being asked', (
    WidgetTester tester,
  ) async {
    await openExplore(tester);

    await openFilters(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Leave these filters?'), findsNothing);
    expect(find.text('Show results'), findsNothing);
  });

  testWidgets('leaving the sheet on purpose drops what was chosen there', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = await openExplore(tester);

    await openFilters(tester);
    await choose(tester, 'Mostar');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsOneWidget);
    expect(catalogue.stayFilters, hasLength(1));
  });

  // A drag closes a sheet by popping its route outright, which would step over
  // the question every other way out of here raises.
  testWidgets('a sheet that answers for itself is not dragged away', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = await openExplore(tester);

    await openFilters(tester);
    await choose(tester, 'Mostar');

    await tester.drag(find.text('Filter stays'), const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(find.text('Show results'), findsOneWidget);
    expect(catalogue.stayFilters, hasLength(1));
  });

  testWidgets('the experience sheet asks what a term is narrowed by', (
    WidgetTester tester,
  ) async {
    final CatalogueDouble catalogue = await openExplore(tester);

    await tester.tap(find.text('Experiences'));
    await tester.pumpAndSettle();
    await openFilters(tester);

    expect(find.text('Places'), findsOneWidget);
    expect(find.text('Length'), findsOneWidget);
    expect(find.text('Amenities'), findsNothing);

    await choose(tester, 'Up to 3 h');
    await apply(tester);

    expect(
      catalogue.lastExperienceFilters,
      const ExperienceFilters(longestMinutes: 180),
    );
  });

  testWidgets('a catalogue with nothing in it offers to drop the filters', (
    WidgetTester tester,
  ) async {
    await openExplore(
      tester,
      catalogue: CatalogueDouble(stays: <Accommodation>[]),
    );

    await openFilters(tester);
    await choose(tester, 'Mostar');
    await apply(tester);

    expect(find.text('No stays match'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('a refusal is answered over the catalogue it was asked of', (
    WidgetTester tester,
  ) async {
    await openExplore(
      tester,
      catalogue: CatalogueDouble(
        failure: const ApiException(message: 'The catalogue is away'),
      ),
    );

    expect(find.text('The catalogue is away'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  // The sheet is still worth opening without its lookup tables: what a reader
  // typed, the dates and the price are all still there to be narrowed by.
  testWidgets('a sheet whose choices were refused says so and still opens', (
    WidgetTester tester,
  ) async {
    await openExplore(
      tester,
      filterOptions: FilterOptionsDouble(
        failure: const ApiException(message: 'The choices are away'),
      ),
    );

    await openFilters(tester);

    expect(find.text('The choices are away'), findsOneWidget);
    expect(find.text('Price per night'), findsOneWidget);
    expect(find.text('City'), findsNothing);
  });

  testWidgets('a stay and a term are each drawn as one card', (
    WidgetTester tester,
  ) async {
    await openExplore(
      tester,
      catalogue: CatalogueDouble(
        stays: <Accommodation>[stay(title: 'Loft over the river')],
        experiences: <Experience>[experience(title: 'Old town walk')],
      ),
    );

    expect(find.widgetWithText(ListingCard, 'Loft over the river'), findsOne);
    expect(find.text('per night'), findsOneWidget);

    await tester.tap(find.text('Experiences'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListingCard, 'Old town walk'), findsOne);
    expect(find.text('per person'), findsOneWidget);
    expect(find.text('3 h'), findsOneWidget);
  });
}
