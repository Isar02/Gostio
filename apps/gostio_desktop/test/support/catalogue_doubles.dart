import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_draft.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_query.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodations_repository.dart';
import 'package:gostio_desktop/features/experiences/data/experience_draft.dart';
import 'package:gostio_desktop/features/experiences/data/experience_query.dart';
import 'package:gostio_desktop/features/experiences/data/experiences_repository.dart';

// Every filter bar that names a listing reads the two catalogues for their
// titles and nothing else. The rest of both repositories is refused here, so
// a test that reaches past what it set up still fails where it stands.
class StaysDouble implements AccommodationsRepository {
  StaysDouble({
    this.titleRows = const <LookupItem>[
      LookupItem(id: 4, name: 'Stone villa on the hill above Neum'),
    ],
  });

  final List<LookupItem> titleRows;
  final List<int?> hostIds = <int?>[];

  @override
  Future<List<LookupItem>> titles({int? hostId}) async {
    hostIds.add(hostId);

    return titleRows;
  }

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
  }) => throw UnimplementedError();
}

class TermsDouble implements ExperiencesRepository {
  TermsDouble({
    this.titleRows = const <LookupItem>[
      LookupItem(id: 12, name: 'Rafting the Neretva canyon'),
    ],
  });

  final List<LookupItem> titleRows;
  final List<int?> hostIds = <int?>[];

  @override
  Future<List<LookupItem>> titles({int? hostId}) async {
    hostIds.add(hostId);

    return titleRows;
  }

  @override
  Future<Experience> get(int id) => throw UnimplementedError();

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
  }) => throw UnimplementedError();
}
