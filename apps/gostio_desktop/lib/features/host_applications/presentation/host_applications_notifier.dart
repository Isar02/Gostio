import '../../../core/models/paged_result.dart';
import '../../../core/paging/paged_notifier.dart';
import '../data/host_application.dart';
import '../data/host_application_query.dart';
import '../data/host_applications_repository.dart';

class HostApplicationsNotifier
    extends PagedNotifier<HostApplication, HostApplicationQuery> {
  HostApplicationsNotifier(this._applications)
    : super(const HostApplicationQuery());

  final HostApplicationsRepository _applications;

  @override
  Future<PagedResult<HostApplication>> fetch({
    required int page,
    required HostApplicationQuery query,
  }) => _applications.search(query: query, page: page, pageSize: pageSize);
}
