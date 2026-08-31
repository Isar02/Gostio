import '../../../core/authorization/role_names.dart';
import '../../../core/models/user.dart';
import '../../../core/network/api_client.dart';
import '../../../core/paging/page_walk.dart';

class UsersRepository {
  const UsersRepository(this._client);

  final ApiClient _client;

  Future<List<User>> hosts() => readEveryPage<User>(
    _client,
    '/users',
    read: User.fromJson,
    query: <String, dynamic>{'role': RoleNames.host, 'isActive': true},
  );
}
