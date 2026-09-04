import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/users/data/user_query.dart';
import 'package:gostio_desktop/features/users/presentation/users_notifier.dart';

import '../../../support/account_fixture.dart';
import '../../../support/users_double.dart';

void main() {
  test('a filter is applied from the first page', () async {
    final _Users repository = _Users(totalCount: 60);
    final UsersNotifier notifier = UsersNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.openPage(3);
    await notifier.apply(const UserQuery(role: 'Host'));

    expect(notifier.page, 1);
    expect(repository.pages, <int>[3, 1]);
  });

  test('the rows on screen say which query fetched them', () async {
    final _Users repository = _Users();
    final UsersNotifier notifier = UsersNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.apply(const UserQuery(name: 'Lamija', isActive: true));

    expect(notifier.query.name, 'Lamija');
    expect(repository.queries.last.toParameters(), <String, dynamic>{
      'name': 'Lamija',
      'isActive': true,
    });
  });
}

class _Users extends UsersDouble {
  _Users({this.totalCount = 1});

  final int totalCount;
  final List<int> pages = <int>[];
  final List<UserQuery> queries = <UserQuery>[];

  @override
  Future<PagedResult<User>> search({
    required UserQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    pages.add(page);
    queries.add(query);

    return PagedResult<User>(
      items: <User>[account()],
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }
}
