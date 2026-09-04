import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/experience_query.dart';
import '../data/experiences_repository.dart';

class ExperiencesNotifier extends PagedNotifier<Experience, ExperienceQuery> {
  ExperiencesNotifier(this._repository, {this.hostId})
    : super(const ExperienceQuery());

  final ExperiencesRepository _repository;

  // Set in the host panel, where the list is the caller's own rather than the
  // catalogue. It is not a filter, so clearing the filters cannot take it off.
  final int? hostId;

  @override
  Future<PagedResult<Experience>> fetch({
    required int page,
    required ExperienceQuery query,
  }) => _repository.search(
    query: query,
    page: page,
    pageSize: pageSize,
    hostId: hostId,
  );
}
