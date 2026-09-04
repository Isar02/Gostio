import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_amenities_repository.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_availability_repository.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_draft.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_query.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodations_repository.dart';
import 'package:gostio_desktop/features/accommodations/data/availability_draft.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_detail_notifier.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_detail_screen.dart';
import 'package:gostio_desktop/features/reference/data/reference_repository.dart';
import 'package:gostio_desktop/features/reservations/data/reservations_repository.dart';
import 'package:gostio_desktop/features/users/data/users_repository.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/bookings_double.dart';
import '../../../support/reference_double.dart';
import '../../../support/users_double.dart';

void main() {
  testWidgets(
    'a create that could not read its tables says what the API said',
    (WidgetTester tester) async {
      await tester.pumpWidget(_screen(failing: true));
      await tester.pumpAndSettle();

      expect(find.text('The cities could not be read.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Trace 9f2c41'), findsOneWidget);
      expect(
        find.textContaining('Nothing to build a listing on'),
        findsNothing,
      );
    },
  );

  testWidgets('a table that really is empty is named as the reason', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(empty: true));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Nothing to build a listing on'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
  });

  // The refusal is what the form was written for, so the screen it is said on
  // has to still be there: a write that failed is not a page that could not be
  // read, and emptying the form would throw away everything typed into it.
  testWidgets('a refused create keeps the form it was typed into', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(refusing: true));
    await tester.pumpAndSettle();

    await tester
        .element(find.byType(TabBarView))
        .read<AccommodationDetailNotifier>()
        .save(_draft, isActive: true);
    await tester.pumpAndSettle();

    expect(find.text('Create listing'), findsOneWidget);
    expect(find.text('A listing already goes by that title.'), findsOne);
  });

  // The form empties for the next listing rather than closing, so a screen
  // that opened a calendar over the one just created would carry it into the
  // one after that: the tabs stay shut until a listing is opened from the list.
  testWidgets('a listing created from the empty form opens no tab of its own', (
    WidgetTester tester,
  ) async {
    final _Availability availability = _Availability();
    final _Offerings offerings = _Offerings();
    await tester.pumpWidget(
      _screen(availability: availability, offerings: offerings),
    );
    await tester.pumpAndSettle();

    await tester
        .element(find.byType(TabBarView))
        .read<AccommodationDetailNotifier>()
        .save(_draft, isActive: true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Availability'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('before availability can be managed'),
      findsOneWidget,
    );
    expect(availability.windows, isEmpty);

    await tester.tap(find.text('Amenities'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('before amenities can be managed'),
      findsOneWidget,
    );
    expect(offerings.reads, isZero);
  });
}

const AccommodationDraft _draft = AccommodationDraft(
  title: 'Villa Neum',
  description: 'By the sea.',
  accommodationTypeId: 4,
  accommodationCategoryId: 2,
  cityId: 18,
  address: 'Primorska 1',
  latitude: 42.92,
  longitude: 17.61,
  maxGuests: 6,
  bedrooms: 3,
  bathrooms: 2,
  pricePerNight: 180.5,
  cleaningFee: 25,
);

class _Offerings implements AccommodationAmenitiesRepository {
  int reads = 0;

  @override
  Future<List<LookupItem>> forAccommodation(int accommodationId) async {
    reads++;

    return const <LookupItem>[];
  }

  @override
  Future<List<LookupItem>> set(int accommodationId, List<int> amenityIds) =>
      throw UnimplementedError();
}

class _Availability implements AccommodationAvailabilityRepository {
  final List<DateTime> windows = <DateTime>[];

  @override
  Future<List<AccommodationAvailability>> forWindow(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) async {
    windows.add(from);

    return const <AccommodationAvailability>[];
  }

  @override
  Future<AccommodationAvailability> add(
    int accommodationId,
    AvailabilityDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<void> delete(int accommodationId, int availabilityId) =>
      throw UnimplementedError();
}

Widget _screen({
  bool failing = false,
  bool empty = false,
  bool refusing = false,
  AccommodationAvailabilityRepository? availability,
  AccommodationAmenitiesRepository? offerings,
}) => MultiProvider(
  providers: <SingleChildWidget>[
    Provider<AccommodationsRepository>.value(value: _Stays(refusing: refusing)),
    Provider<ReferenceRepository>.value(
      value: _Reference(failing: failing, empty: empty),
    ),
    Provider<UsersRepository>.value(value: _Users()),
    Provider<ReservationsRepository>.value(value: const _Bookings()),
    if (availability case final AccommodationAvailabilityRepository rows)
      Provider<AccommodationAvailabilityRepository>.value(value: rows),
    if (offerings case final AccommodationAmenitiesRepository held)
      Provider<AccommodationAmenitiesRepository>.value(value: held),
  ],
  child: const MaterialApp(
    home: Scaffold(body: AccommodationDetailScreen(asAdministrator: false)),
  ),
);

final Accommodation _created = Accommodation(
  id: 41,
  hostId: 4,
  hostName: 'Lamija',
  title: 'Villa Neum',
  description: 'By the sea.',
  accommodationTypeId: 4,
  accommodationTypeName: 'Villa',
  accommodationCategoryId: 2,
  accommodationCategoryName: 'Seaside',
  cityId: 18,
  cityName: 'Neum',
  countryName: 'Bosnia and Herzegovina',
  address: 'Primorska 1',
  latitude: 42.92,
  longitude: 17.61,
  maxGuests: 6,
  bedrooms: 3,
  bathrooms: 2,
  pricePerNight: 180.5,
  cleaningFee: 25,
  isActive: true,
  reviewCount: 0,
  createdAt: _createdAt,
);

final DateTime _createdAt = DateTime.utc(2026, 1, 1);

class _Reference extends ReferenceDouble {
  _Reference({required this.failing, required this.empty});

  final bool failing;
  final bool empty;

  @override
  Future<List<LookupItem>> cities() async {
    if (failing) {
      throw const ApiException(
        message: 'The cities could not be read.',
        statusCode: 500,
        traceId: '9f2c41',
      );
    }

    return empty
        ? const <LookupItem>[]
        : <LookupItem>[const LookupItem(id: 18, name: 'Neum')];
  }

  @override
  Future<List<LookupItem>> accommodationTypes() async => empty
      ? const <LookupItem>[]
      : <LookupItem>[const LookupItem(id: 4, name: 'Villa')];

  @override
  Future<List<LookupItem>> accommodationCategories() async => empty
      ? const <LookupItem>[]
      : <LookupItem>[const LookupItem(id: 2, name: 'Seaside')];

  @override
  Future<List<LookupItem>> countriesHoldingCities() async =>
      const <LookupItem>[];

  @override
  Future<List<LookupItem>> amenities() async => const <LookupItem>[];
}

class _Users extends UsersDouble {
  @override
  Future<List<User>> hosts() async => const <User>[];
}

class _Stays implements AccommodationsRepository {
  _Stays({this.refusing = false});

  final bool refusing;

  @override
  Future<Accommodation> get(int id) => throw UnimplementedError();

  @override
  Future<List<LookupItem>> titles({int? hostId}) => throw UnimplementedError();

  @override
  Future<Accommodation> create(AccommodationDraft draft, {int? hostId}) async {
    if (refusing) {
      throw const ApiException(
        message: 'A listing already goes by that title.',
        statusCode: 409,
      );
    }

    return _created;
  }

  @override
  Future<Accommodation> update(
    int id,
    AccommodationDraft draft, {
    required bool isActive,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();

  @override
  Future<PagedResult<Accommodation>> search({
    required AccommodationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) => throw UnimplementedError();
}

// The bookings against the listing are read through their own repository,
// which answers get and search where the catalogue answers the same two names.
class _Bookings extends BookingsDouble {
  const _Bookings();

  @override
  Future<int> countForAccommodation(int accommodationId) async => 0;
}
