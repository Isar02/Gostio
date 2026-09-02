import '../../../core/models/paged_result.dart';
import '../../../core/network/api_client.dart';
import 'host_application.dart';
import 'host_application_query.dart';

class HostApplicationsRepository {
  const HostApplicationsRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<HostApplication>> search({
    required HostApplicationQuery query,
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

    return PagedResult<HostApplication>.fromJson(
      body,
      (Object? item) => HostApplication.fromJson(item! as JsonMap),
    );
  }

  Future<HostApplication> get(int id) async =>
      HostApplication.fromJson(await _client.get('$_root/$id'));

  // An approval may go without a reason and a rejection may not, which is the
  // server's rule and the only difference between the two calls.
  Future<HostApplication> approve(int id, {String? reason}) =>
      _decide(id, 'approve', reason);

  Future<HostApplication> reject(int id, {required String reason}) =>
      _decide(id, 'reject', reason);

  Future<HostApplication> _decide(
    int id,
    String decision,
    String? reason,
  ) async => HostApplication.fromJson(
    await _client.post(
      '$_root/$id/$decision',
      body: <String, dynamic>{'reason': ?reason},
    ),
  );

  static const String _root = '/host-verification-requests';
}
