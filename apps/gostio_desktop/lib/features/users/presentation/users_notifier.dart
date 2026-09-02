import '../../../core/models/paged_result.dart';
import '../../../core/models/user.dart';
import '../../../core/paging/paged_notifier.dart';
import '../data/user_query.dart';
import '../data/users_repository.dart';

class UsersNotifier extends PagedNotifier<User, UserQuery> {
  UsersNotifier(this._users) : super(const UserQuery());

  final UsersRepository _users;

  @override
  Future<PagedResult<User>> fetch({
    required int page,
    required UserQuery query,
  }) => _users.search(query: query, page: page, pageSize: pageSize);
}
