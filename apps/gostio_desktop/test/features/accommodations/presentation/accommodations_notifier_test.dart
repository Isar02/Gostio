import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_draft.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_query.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodations_repository.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodations_notifier.dart';

void main() {
  test('the catalogue is asked for without a host', () async {
    final _FakeAccommodationsRepository repository =
        _FakeAccommodationsRepository();
    final AccommodationsNotifier notifier = AccommodationsNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.reload();

    expect(repository.hostIds, <int?>[null]);
  });

  test(
    'clearing the filters does not clear the host the list is for',
    () async {
      final _FakeAccommodationsRepository repository =
          _FakeAccommodationsRepository();
      final AccommodationsNotifier notifier = AccommodationsNotifier(
        repository,
        hostId: 7,
      );
      addTearDown(notifier.dispose);

      await notifier.apply(const AccommodationQuery(title: 'Villa'));
      await notifier.apply(const AccommodationQuery());

      expect(repository.hostIds, <int?>[7, 7]);
      expect(repository.queries.last.toParameters(), isEmpty);
    },
  );

  test('a filter is applied from the first page', () async {
    final _FakeAccommodationsRepository repository =
        _FakeAccommodationsRepository(totalCount: 60);
    final AccommodationsNotifier notifier = AccommodationsNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.openPage(3);
    await notifier.apply(const AccommodationQuery(minGuests: 4));

    expect(notifier.page, 1);
    expect(repository.pages, <int>[3, 1]);
  });
}

class _FakeAccommodationsRepository implements AccommodationsRepository {
  _FakeAccommodationsRepository({this.totalCount = 1});

  final int totalCount;
  final List<int?> hostIds = <int?>[];
  final List<int> pages = <int>[];
  final List<AccommodationQuery> queries = <AccommodationQuery>[];

  // The list is what this double is for; reaching anything else is the test
  // asking the wrong question.
  @override
  Future<Accommodation> get(int id) => throw UnimplementedError();

  @override
  Future<Accommodation> create(AccommodationDraft draft, {int? hostId}) =>
      throw UnimplementedError();

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
  }) async {
    hostIds.add(hostId);
    pages.add(page);
    queries.add(query);

    return PagedResult<Accommodation>(
      items: <Accommodation>[_accommodation()],
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }
}

Accommodation _accommodation() => Accommodation(
  id: 1,
  hostId: 7,
  hostName: 'Host',
  title: 'Villa',
  description: 'A villa.',
  accommodationTypeId: 1,
  accommodationTypeName: 'Villa',
  accommodationCategoryId: 1,
  accommodationCategoryName: 'Seaside',
  cityId: 1,
  cityName: 'Neum',
  countryName: 'Bosnia and Herzegovina',
  address: 'A street',
  latitude: 42.9,
  longitude: 17.6,
  maxGuests: 4,
  bedrooms: 2,
  bathrooms: 1,
  pricePerNight: 120,
  cleaningFee: 20,
  isActive: true,
  reviewCount: 0,
  createdAt: DateTime.utc(2026, 1, 1),
);
