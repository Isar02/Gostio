import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/core/models/user.dart';
import 'package:gostio_desktop/features/users/data/user_draft.dart';
import 'package:gostio_desktop/features/users/data/user_query.dart';
import 'package:gostio_desktop/features/users/data/users_repository.dart';

// Four listing forms reach this repository for the hosts alone, and the
// account screens reach a different part of it each. Everything a test does
// not ask for is refused here once rather than restated as a stub, so a test
// that reaches past what it set up still fails where it stands.
class UsersDouble implements UsersRepository {
  const UsersDouble();

  @override
  Future<PagedResult<User>> search({
    required UserQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) => throw UnimplementedError();

  @override
  Future<User> get(int id) => throw UnimplementedError();

  @override
  Future<User> create(
    UserDraft draft, {
    required String username,
    required String password,
    required String confirmPassword,
    required List<String> roles,
  }) => throw UnimplementedError();

  @override
  Future<User> update(int id, UserDraft draft) => throw UnimplementedError();

  @override
  Future<User> setRoles(int id, List<String> roles) =>
      throw UnimplementedError();

  @override
  Future<User> setState(int id, {required bool isActive}) =>
      throw UnimplementedError();

  @override
  Future<void> setPassword(
    int id, {
    required String password,
    required String confirmPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();

  @override
  Future<List<User>> hosts() => throw UnimplementedError();
}
