import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/experiences/data/experience_draft.dart';
import 'package:gostio_desktop/features/experiences/data/experience_query.dart';
import 'package:gostio_desktop/features/experiences/data/experiences_repository.dart';
import 'package:gostio_desktop/features/experiences/presentation/experiences_notifier.dart';

void main() {
  test('the catalogue is asked for without a host', () async {
    final _Experiences repository = _Experiences();
    final ExperiencesNotifier notifier = ExperiencesNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.reload();

    expect(repository.hostIds, <int?>[null]);
  });

  test(
    'clearing the filters does not clear the host the list is for',
    () async {
      final _Experiences repository = _Experiences();
      final ExperiencesNotifier notifier = ExperiencesNotifier(
        repository,
        hostId: 7,
      );
      addTearDown(notifier.dispose);

      await notifier.apply(const ExperienceQuery(title: 'Rafting'));
      await notifier.apply(const ExperienceQuery());

      expect(repository.hostIds, <int?>[7, 7]);
      expect(repository.queries.last.toParameters(), isEmpty);
    },
  );

  test('a filter is applied from the first page', () async {
    final _Experiences repository = _Experiences(totalCount: 60);
    final ExperiencesNotifier notifier = ExperiencesNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.openPage(3);
    await notifier.apply(const ExperienceQuery(maxDurationMinutes: 120));

    expect(notifier.page, 1);
    expect(repository.pages, <int>[3, 1]);
  });
}

class _Experiences implements ExperiencesRepository {
  _Experiences({this.totalCount = 1});

  final int totalCount;
  final List<int?> hostIds = <int?>[];
  final List<int> pages = <int>[];
  final List<ExperienceQuery> queries = <ExperienceQuery>[];

  // The list is what this double is for; reaching anything else is the test
  // asking the wrong question.
  @override
  Future<Experience> get(int id) => throw UnimplementedError();

  @override
  Future<List<LookupItem>> titles({int? hostId}) => throw UnimplementedError();

  @override
  Future<Experience> create(ExperienceDraft draft, {int? hostId}) =>
      throw UnimplementedError();

  @override
  Future<Experience> update(
    int id,
    ExperienceDraft draft, {
    required bool isActive,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();

  @override
  Future<PagedResult<Experience>> search({
    required ExperienceQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) async {
    hostIds.add(hostId);
    pages.add(page);
    queries.add(query);

    return PagedResult<Experience>(
      items: <Experience>[_experience()],
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }
}

Experience _experience() => Experience(
  id: 1,
  hostId: 7,
  hostName: 'Host',
  title: 'Rafting the Neretva canyon',
  description: 'Down the green water.',
  experienceCategoryId: 3,
  experienceCategoryName: 'Adventure',
  cityId: 11,
  cityName: 'Konjic',
  countryName: 'Bosnia and Herzegovina',
  meetingPoint: 'The old bridge',
  latitude: 43.65,
  longitude: 17.96,
  durationMinutes: 240,
  pricePerPerson: 85,
  isActive: true,
  reviewCount: 0,
  isFavorite: false,
  createdAt: DateTime.utc(2026, 1, 1),
);
