import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/core/models/user.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_availability.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_availability_repository.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_draft.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_query.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodations_repository.dart';
import 'package:gostio_desktop/features/accommodations/data/availability_draft.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_detail_notifier.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_detail_screen.dart';
import 'package:gostio_desktop/features/reference/data/lookup_item.dart';
import 'package:gostio_desktop/features/reference/data/reference_repository.dart';
import 'package:gostio_desktop/features/reservations/data/reservation.dart';
import 'package:gostio_desktop/features/reservations/data/reservations_repository.dart';
import 'package:gostio_desktop/features/users/data/users_repository.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

void main() {
  testWidgets(
    'a create that could not read its tables says what the API said',
    (WidgetTester tester) async {
      await tester.pumpWidget(_screen(_Repositories(failing: true)));
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
    await tester.pumpWidget(_screen(_Repositories(empty: true)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Nothing to build a listing on'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
  });

  // The form empties for the next listing rather than closing, so a screen
  // that opened a calendar over the one just created would carry it into the
  // one after that: the tabs stay shut until a listing is opened from the list.
  testWidgets('a listing created from the empty form opens no calendar', (
    WidgetTester tester,
  ) async {
    final _Availability availability = _Availability();
    await tester.pumpWidget(_screen(_Repositories(), availability));
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

Widget _screen(
  _Repositories repositories, [
  AccommodationAvailabilityRepository? availability,
]) => MultiProvider(
  providers: <SingleChildWidget>[
    Provider<AccommodationsRepository>.value(value: repositories),
    Provider<ReferenceRepository>.value(value: repositories),
    Provider<UsersRepository>.value(value: repositories),
    Provider<ReservationsRepository>.value(value: repositories),
    if (availability case final AccommodationAvailabilityRepository rows)
      Provider<AccommodationAvailabilityRepository>.value(value: rows),
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

class _Repositories
    implements
        AccommodationsRepository,
        ReferenceRepository,
        UsersRepository,
        ReservationsRepository {
  _Repositories({this.failing = false, this.empty = false});

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
  Future<List<LookupItem>> countries() async => const <LookupItem>[];

  @override
  Future<List<LookupItem>> amenities() async => const <LookupItem>[];

  @override
  Future<LookupItem> addCity({required String name, required int countryId}) =>
      throw UnimplementedError();

  @override
  Future<List<User>> hosts() async => const <User>[];

  @override
  Future<int> countForAccommodation(int accommodationId) async => 0;

  @override
  Future<List<Reservation>> forAccommodationWindow(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) => throw UnimplementedError();

  @override
  Future<Accommodation> get(int id) => throw UnimplementedError();

  @override
  Future<Accommodation> create(AccommodationDraft draft, {int? hostId}) async =>
      _created;

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
