import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/models/image_upload.dart';
import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/core/models/user.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/experiences/data/experience.dart';
import 'package:gostio_desktop/features/experiences/data/experience_draft.dart';
import 'package:gostio_desktop/features/experiences/data/experience_query.dart';
import 'package:gostio_desktop/features/experiences/data/experience_slot.dart';
import 'package:gostio_desktop/features/experiences/data/experience_slot_query.dart';
import 'package:gostio_desktop/features/experiences/data/experience_slots_repository.dart';
import 'package:gostio_desktop/features/experiences/data/experiences_repository.dart';
import 'package:gostio_desktop/features/experiences/presentation/experience_detail_notifier.dart';
import 'package:gostio_desktop/features/experiences/presentation/experience_detail_screen.dart';
import 'package:gostio_desktop/features/listings/data/listing_address.dart';
import 'package:gostio_desktop/features/listings/data/listing_photo.dart';
import 'package:gostio_desktop/features/listings/data/listing_photos_repository.dart';
import 'package:gostio_desktop/features/reference/data/lookup_item.dart';
import 'package:gostio_desktop/features/reference/data/reference_repository.dart';
import 'package:gostio_desktop/features/reservations/data/reservations_repository.dart';
import 'package:gostio_desktop/features/users/data/users_repository.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/bookings_double.dart';

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
        find.textContaining('Nothing to build an experience on'),
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
      find.textContaining('Nothing to build an experience on'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
  });

  // The form empties for the next experience rather than closing, so a screen
  // that opened the terms over the one just created would carry them into the
  // one after that: the tabs stay shut until one is opened from the list.
  testWidgets('an experience created from the empty form opens no tab', (
    WidgetTester tester,
  ) async {
    final _Slots slots = _Slots();
    await tester.pumpWidget(_screen(_Repositories(), slots: slots));
    await tester.pumpAndSettle();

    await tester
        .element(find.byType(TabBarView))
        .read<ExperienceDetailNotifier>()
        .save(_draft, isActive: true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terms'));
    await tester.pumpAndSettle();

    expect(find.textContaining('before terms can be managed'), findsOneWidget);
    expect(slots.reads, 0);
  });

  testWidgets('an experience opened from the list carries its terms', (
    WidgetTester tester,
  ) async {
    final _Slots slots = _Slots();
    await tester.pumpWidget(
      _screen(_Repositories(), slots: slots, experienceId: 12),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terms'));
    await tester.pumpAndSettle();

    expect(slots.reads, 1);
    expect(find.text('Add term'), findsOneWidget);
  });
}

Widget _screen(
  _Repositories repositories, {
  _Slots? slots,
  int? experienceId,
}) => MultiProvider(
  providers: <SingleChildWidget>[
    Provider<ExperiencesRepository>.value(value: repositories),
    Provider<ReferenceRepository>.value(value: repositories),
    Provider<UsersRepository>.value(value: repositories),
    Provider<ReservationsRepository>.value(value: const _Bookings()),
    Provider<ExperienceSlotsRepository>.value(value: slots ?? _Slots()),
    Provider<ListingPhotosRepository>.value(value: _Photos()),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: ExperienceDetailScreen(
        asAdministrator: false,
        experienceId: experienceId,
      ),
    ),
  ),
);

class _Repositories
    implements ExperiencesRepository, ReferenceRepository, UsersRepository {
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
        : <LookupItem>[const LookupItem(id: 11, name: 'Konjic')];
  }

  @override
  Future<List<LookupItem>> experienceCategories() async => empty
      ? const <LookupItem>[]
      : <LookupItem>[const LookupItem(id: 3, name: 'Adventure')];

  @override
  Future<List<LookupItem>> accommodationTypes() async => const <LookupItem>[];

  @override
  Future<List<LookupItem>> accommodationCategories() async =>
      const <LookupItem>[];

  @override
  Future<List<LookupItem>> amenities() async => const <LookupItem>[];

  @override
  Future<List<LookupItem>> countries() async => const <LookupItem>[];

  @override
  Future<LookupItem> addCity({required String name, required int countryId}) =>
      throw UnimplementedError();

  @override
  Future<List<User>> hosts() async => const <User>[];

  @override
  Future<List<LookupItem>> reservationStatuses() async => const <LookupItem>[];

  @override
  Future<Experience> get(int id) async => _experience();

  @override
  Future<List<LookupItem>> titles({int? hostId}) => throw UnimplementedError();

  @override
  Future<Experience> create(ExperienceDraft draft, {int? hostId}) async =>
      _experience();

  @override
  Future<Experience> update(
    int id,
    ExperienceDraft draft, {
    required bool isActive,
  }) async => _experience();

  @override
  Future<void> delete(int id) async {}

  @override
  Future<PagedResult<Experience>> search({
    required ExperienceQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) => throw UnimplementedError();
}

class _Slots implements ExperienceSlotsRepository {
  int reads = 0;

  @override
  Future<PagedResult<ExperienceSlot>> search(
    int experienceId, {
    required ExperienceSlotQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    reads++;

    return PagedResult<ExperienceSlot>(
      items: const <ExperienceSlot>[],
      page: page,
      pageSize: pageSize,
      totalCount: 0,
    );
  }

  @override
  Future<ExperienceSlot> get(int experienceId, int slotId) =>
      throw UnimplementedError();

  @override
  Future<ExperienceSlot> add(
    int experienceId, {
    required DateTime startTime,
    required int capacity,
  }) => throw UnimplementedError();

  @override
  Future<ExperienceSlot> update(
    int experienceId,
    int slotId, {
    required int capacity,
    required bool isActive,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(int experienceId, int slotId) =>
      throw UnimplementedError();
}

class _Photos implements ListingPhotosRepository {
  @override
  Future<List<ListingPhoto>> forListing(ListingAddress listing) async =>
      const <ListingPhoto>[];

  @override
  Future<ListingPhoto> upload(ListingAddress listing, ImageUpload image) =>
      throw UnimplementedError();

  @override
  Future<ListingPhoto> setCover(ListingAddress listing, int photoId) =>
      throw UnimplementedError();

  @override
  Future<void> delete(ListingAddress listing, int photoId) =>
      throw UnimplementedError();
}

const ExperienceDraft _draft = ExperienceDraft(
  title: 'Rafting the Neretva canyon',
  description: 'Down the green water.',
  experienceCategoryId: 3,
  cityId: 11,
  meetingPoint: 'The old bridge in Konjic',
  latitude: 43.65,
  longitude: 17.96,
  durationMinutes: 240,
  pricePerPerson: 85.5,
);

Experience _experience() => Experience(
  id: 12,
  hostId: 7,
  hostName: 'Host',
  title: 'Rafting the Neretva canyon',
  description: 'Down the green water.',
  experienceCategoryId: 3,
  experienceCategoryName: 'Adventure',
  cityId: 11,
  cityName: 'Konjic',
  countryName: 'Bosnia and Herzegovina',
  meetingPoint: 'The old bridge in Konjic',
  latitude: 43.65,
  longitude: 17.96,
  durationMinutes: 240,
  pricePerPerson: 85.5,
  isActive: true,
  reviewCount: 0,
  createdAt: DateTime.utc(2026, 1, 1),
);

// The bookings against the experience are read through their own repository,
// which answers get and search where the catalogue answers the same two names.
class _Bookings extends BookingsDouble {
  const _Bookings();

  @override
  Future<int> countForExperience(int experienceId) async => 0;

  @override
  Future<int> countForSlot(int slotId) async => 0;
}
