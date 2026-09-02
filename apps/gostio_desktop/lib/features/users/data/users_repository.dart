import '../../../core/authorization/role_names.dart';
import '../../../core/models/paged_result.dart';
import '../../../core/models/user.dart';
import '../../../core/network/api_client.dart';
import '../../../core/paging/page_walk.dart';
import 'user_draft.dart';
import 'user_query.dart';

class UsersRepository {
  const UsersRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<User>> search({
    required UserQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    final JsonMap body = await _client.get(
      _root,
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        ...query.toParameters(),
      },
    );

    return PagedResult<User>.fromJson(
      body,
      (Object? item) => User.fromJson(item! as JsonMap),
    );
  }

  Future<User> get(int id) async =>
      User.fromJson(await _client.get('$_root/$id'));

  Future<User> create(
    UserDraft draft, {
    required String username,
    required String password,
    required String confirmPassword,
    required List<String> roles,
  }) async => User.fromJson(
    await _client.post(
      _root,
      body: draft.toCreate(
        username: username,
        password: password,
        confirmPassword: confirmPassword,
        roles: roles,
      ),
    ),
  );

  Future<User> update(int id, UserDraft draft) async =>
      User.fromJson(await _client.put('$_root/$id', body: draft.toUpdate()));

  Future<User> setRoles(int id, List<String> roles) async => User.fromJson(
    await _client.put(
      '$_root/$id/roles',
      body: <String, dynamic>{'roles': roles},
    ),
  );

  Future<User> setState(int id, {required bool isActive}) async =>
      User.fromJson(
        await _client.put(
          '$_root/$id/state',
          body: <String, dynamic>{'isActive': isActive},
        ),
      );

  // The only write here that answers nothing: an administrator setting a
  // password reads nothing back and the account is signed out by it.
  Future<void> setPassword(
    int id, {
    required String password,
    required String confirmPassword,
  }) => _client.putNoContent(
    '$_root/$id/password',
    body: <String, dynamic>{
      'newPassword': password,
      'confirmNewPassword': confirmPassword,
    },
  );

  Future<void> delete(int id) => _client.delete('$_root/$id');

  Future<List<User>> hosts() => readEveryPage<User>(
    _client,
    _root,
    read: User.fromJson,
    query: <String, dynamic>{'role': RoleNames.host, 'isActive': true},
  );

  static const String _root = '/users';
}
