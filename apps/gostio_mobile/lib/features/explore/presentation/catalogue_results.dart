import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/catalogue_repository.dart';
import '../data/experience_filters.dart';
import '../data/stay_filters.dart';

// One catalogue's results. The pair is written here rather than behind a
// common base, because all they would share is the call they each make to a
// different route with a different filter — which is the whole of them.
//
// Neither reads on being made. Only one of the two is in front at a time, and
// which of them is being looked at is the screen's to know.
class StayResults extends PagedNotifier<Accommodation, StayFilters> {
  StayResults(this._repository) : super(const StayFilters());

  final CatalogueRepository _repository;

  @override
  @protected
  Future<PagedResult<Accommodation>> fetch({
    required int page,
    required StayFilters query,
  }) => _repository.stays(filters: query, page: page, pageSize: pageSize);
}

class ExperienceResults extends PagedNotifier<Experience, ExperienceFilters> {
  ExperienceResults(this._repository) : super(const ExperienceFilters());

  final CatalogueRepository _repository;

  @override
  @protected
  Future<PagedResult<Experience>> fetch({
    required int page,
    required ExperienceFilters query,
  }) => _repository.experiences(filters: query, page: page, pageSize: pageSize);
}
