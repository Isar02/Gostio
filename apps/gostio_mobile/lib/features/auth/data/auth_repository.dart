import 'package:gostio_core/gostio_core.dart';

import 'account_registration.dart';

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

  Future<AuthResult> register(AccountRegistration registration) async {
    final JsonMap body = await _client.post(
      '/auth/register',
      body: registration.toJson(),
    );

    return AuthResult.fromJson(body);
  }

  Future<User> me() async => User.fromJson(await _client.get('/auth/me'));

  // The API answers the same whether or not the address belongs to an account,
  // so nothing here can tell one from the other either.
  Future<void> forgotPassword(String email) => _client.postNoContent(
    '/auth/forgot-password',
    body: <String, String>{'email': email},
  );

  Future<void> resetPassword({
    required String code,
    required String newPassword,
    required String confirmNewPassword,
  }) => _client.postNoContent(
    '/auth/reset-password',
    body: <String, String>{
      'token': code,
      'newPassword': newPassword,
      'confirmNewPassword': confirmNewPassword,
    },
  );

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
