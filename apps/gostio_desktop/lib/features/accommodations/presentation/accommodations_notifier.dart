import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/accommodation_query.dart';
import '../data/accommodations_repository.dart';

class AccommodationsNotifier
    extends PagedNotifier<Accommodation, AccommodationQuery> {
  AccommodationsNotifier(this._repository, {this.hostId})
    : super(const AccommodationQuery());

  final AccommodationsRepository _repository;

  // Set in the host panel, where the list is the caller's own rather than the
  // catalogue. It is not a filter, so clearing the filters cannot take it off.
  final int? hostId;

  @override
  Future<PagedResult<Accommodation>> fetch({
    required int page,
    required AccommodationQuery query,
  }) => _repository.search(
    query: query,
    page: page,
    pageSize: pageSize,
    hostId: hostId,
  );
}
