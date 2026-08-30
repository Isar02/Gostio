import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'auth_result.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final ApiClient _client;

  Future<AuthResult> signIn({
    required String username,
    required String password,
  }) async {
    final JsonMap body = await _client.post(
      '/auth/login',
      body: <String, String>{'username': username, 'password': password},
    );

    return AuthResult.fromJson(body);
  }

  Future<void> signOut() async {
    try {
      await _client.postNoContent('/auth/logout');
    } on ApiException catch (failure) {
      // A token the server has already refused is the state this call was
      // going to produce.
      if (!failure.isUnauthorized) {
        rethrow;
      }
    }
  }
}
