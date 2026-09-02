import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/features/host_applications/data/host_application.dart';
import 'package:gostio_desktop/features/host_applications/data/host_application_query.dart';
import 'package:gostio_desktop/features/host_applications/data/host_application_status.dart';
import 'package:gostio_desktop/features/host_applications/data/host_applications_repository.dart';
import 'package:gostio_desktop/features/host_applications/presentation/host_applications_notifier.dart';

import '../../../support/application_fixture.dart';

void main() {
  test('a filter is applied from the first page', () async {
    final _Applications repository = _Applications(totalCount: 60);
    final HostApplicationsNotifier notifier = HostApplicationsNotifier(
      repository,
    );
    addTearDown(notifier.dispose);

    await notifier.openPage(3);
    await notifier.apply(
      const HostApplicationQuery(status: HostApplicationStatus.pending),
    );

    expect(notifier.page, 1);
    expect(repository.pages, <int>[3, 1]);
    expect(repository.queries.last.toParameters(), <String, dynamic>{
      'status': 'Pending',
    });
  });
}

class _Applications implements HostApplicationsRepository {
  _Applications({this.totalCount = 1});

  final int totalCount;
  final List<int> pages = <int>[];
  final List<HostApplicationQuery> queries = <HostApplicationQuery>[];

  @override
  Future<PagedResult<HostApplication>> search({
    required HostApplicationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    pages.add(page);
    queries.add(query);

    return PagedResult<HostApplication>(
      items: <HostApplication>[application()],
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }

  @override
  Future<HostApplication> get(int id) => throw UnimplementedError();

  @override
  Future<HostApplication> approve(int id, {String? reason}) =>
      throw UnimplementedError();

  @override
  Future<HostApplication> reject(int id, {required String reason}) =>
      throw UnimplementedError();
}
