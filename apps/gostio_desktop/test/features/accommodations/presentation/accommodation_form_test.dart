import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_draft.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_query.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodations_repository.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_detail_notifier.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_form.dart';

import '../../../support/bookings_double.dart';
import '../../../support/reference_double.dart';
import '../../../support/users_double.dart';

void main() {
  testWidgets('a listing is not created until the map and the lists answer', (
    WidgetTester tester,
  ) async {
    final _Stays stays = _Stays();
    final AccommodationDetailNotifier notifier = await _notifier(stays);

    await tester.pumpWidget(_form(notifier));
    await tester.tap(find.text('Create listing'));
    await tester.pump();

    expect(stays.created, isNull);
    expect(find.text('Enter a title.'), findsOneWidget);
    expect(find.text('Choose the type of accommodation.'), findsOneWidget);
    expect(
      find.text('Choose the city this accommodation is in.'),
      findsOneWidget,
    );
    expect(find.text('Choose the place on the map.'), findsOneWidget);
  });

  testWidgets('editing asks nothing of a field the listing already answers', (
    WidgetTester tester,
  ) async {
    final _Stays stays = _Stays();
    final AccommodationDetailNotifier notifier = await _notifier(
      stays,
      accommodationId: 1,
    );

    await tester.pumpWidget(_form(notifier));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final AccommodationDraft? written = stays.updated;

    expect(written, isNotNull);
    expect(written!.title, 'Villa Neum');
    expect(written.cityId, 18);
    expect(written.accommodationTypeId, 4);
    expect(written.latitude, 42.92);
    expect(written.pricePerNight, 180.5);
    expect(stays.updatedActive, isTrue);
  });
  testWidgets('a form left while it saves does not reach for a dead screen', (
    WidgetTester tester,
  ) async {
    final Completer<void> saving = Completer<void>();
    final _Stays stays = _Stays(gate: saving);
    final AccommodationDetailNotifier notifier = await _notifier(
      stays,
      accommodationId: 1,
    );
    bool reported = false;

    await tester.pumpWidget(
      _form(notifier, onSaved: (Accommodation _) => reported = true),
    );
    await tester.tap(find.text('Save changes'));
    await tester.pump();

    // Back, while the save is still in flight.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    saving.complete();
    await tester.pumpAndSettle();

    expect(reported, isFalse);
    expect(tester.takeException(), isNull);
  });
}

Future<AccommodationDetailNotifier> _notifier(
  _Stays stays, {
  int? accommodationId,
}) async {
  final AccommodationDetailNotifier notifier = AccommodationDetailNotifier(
    stays,
    _Reference(),
    _Users(),
    const _Bookings(),
    accommodationId: accommodationId,
    asAdministrator: false,
  );

  await notifier.load();

  return notifier;
}

Widget _form(
  AccommodationDetailNotifier notifier, {
  ValueChanged<Accommodation>? onSaved,
}) => MaterialApp(
  home: Scaffold(
    body: AccommodationForm(
      notifier: notifier,
      onSaved: onSaved ?? (Accommodation _) {},
      onDeleted: (Accommodation _) {},
    ),
  ),
);

Accommodation _listing() => Accommodation(
  id: 1,
  hostId: 7,
  hostName: 'Host',
  title: 'Villa Neum',
  description: 'Above the bay.',
  accommodationTypeId: 4,
  accommodationTypeName: 'Villa',
  accommodationCategoryId: 2,
  accommodationCategoryName: 'Seaside',
  cityId: 18,
  cityName: 'Neum',
  countryName: 'Bosnia and Herzegovina',
  address: 'Primorska 12',
  latitude: 42.92,
  longitude: 17.61,
  maxGuests: 6,
  bedrooms: 3,
  bathrooms: 2,
  pricePerNight: 180.5,
  cleaningFee: 25,
  isActive: true,
  reviewCount: 0,
  isFavorite: false,
  createdAt: DateTime.utc(2026, 1, 1),
);

class _Stays implements AccommodationsRepository {
  _Stays({this.gate});

  // Held open so a test can leave the screen while the write is in flight.
  final Completer<void>? gate;

  AccommodationDraft? created;
  AccommodationDraft? updated;
  bool? updatedActive;

  @override
  Future<Accommodation> get(int id) async => _listing();

  @override
  Future<List<LookupItem>> titles({int? hostId}) => throw UnimplementedError();

  @override
  Future<Accommodation> create(AccommodationDraft draft, {int? hostId}) async {
    created = draft;

    return _listing();
  }

  @override
  Future<Accommodation> update(
    int id,
    AccommodationDraft draft, {
    required bool isActive,
  }) async {
    await gate?.future;
    updated = draft;
    updatedActive = isActive;

    return _listing();
  }

  @override
  Future<void> delete(int id) async {}

  @override
  Future<PagedResult<Accommodation>> search({
    required AccommodationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) => throw UnimplementedError();
}

class _Reference extends ReferenceDouble {
  @override
  Future<List<LookupItem>> cities() async => <LookupItem>[
    const LookupItem(id: 18, name: 'Neum'),
  ];

  @override
  Future<List<LookupItem>> accommodationTypes() async => <LookupItem>[
    const LookupItem(id: 4, name: 'Villa'),
  ];

  @override
  Future<List<LookupItem>> accommodationCategories() async => <LookupItem>[
    const LookupItem(id: 2, name: 'Seaside'),
  ];

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

// The bookings against the listing are read through their own repository,
// which answers get and search where the catalogue answers the same two names.
class _Bookings extends BookingsDouble {
  const _Bookings();

  @override
  Future<int> countForAccommodation(int accommodationId) async => 0;
}
