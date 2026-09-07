import 'package:gostio_core/gostio_core.dart';

// What a guest may do about hosting: read where their own application stands,
// and make one. Answering an application is an administrator's act and is on
// the other client.
//
// Neither call names an account. The search route narrows itself to the
// caller's own rows, and the application carries whoever the token says is
// asking, so reading or applying for somebody else is not something this
// client can express.
class HostApplicationRepository {
  const HostApplicationRepository(this._client);

  final ApiClient _client;

  // The newest application this account has made, or none at all. Only one may
  // be waiting at a time and the server answers newest first, so the first row
  // is where this account stands today and the ones behind it are history.
  Future<HostApplication?> mine() async {
    final JsonMap body = await _client.get(
      _root,
      query: <String, dynamic>{'page': 1, 'pageSize': 1},
    );

    final PagedResult<HostApplication> answered =
        PagedResult<HostApplication>.fromJson(
          body,
          (Object? item) => HostApplication.fromJson(item! as JsonMap),
        );

    return answered.items.isEmpty ? null : answered.items.first;
  }

  Future<HostApplication> apply() async =>
      HostApplication.fromJson(await _client.post(_root));

  static const String _root = '/host-verification-requests';
}
