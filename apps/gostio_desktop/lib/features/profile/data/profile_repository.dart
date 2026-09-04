import '../../../core/models/image_upload.dart';
import '../../../core/models/user.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_result.dart';
import '../../users/data/user_draft.dart';

// The account the token belongs to. Not one route here names an id: who is
// asking is the token's answer, and an id the client could type would make
// this the administrator's endpoint under another name.
class ProfileRepository {
  const ProfileRepository(this._client);

  static const String fileField = 'File';

  final ApiClient _client;

  Future<User> mine() async => User.fromJson(await _client.get('$_root/me'));

  Future<User> update(UserDraft draft) async =>
      User.fromJson(await _client.put('$_root/me', body: draft.toUpdate()));

  Future<User> setPicture(ImageUpload picture) async => User.fromJson(
    await _client.putForm(
      '$_root/me/image',
      file: picture.underField(fileField),
    ),
  );

  // The endpoint answers nothing, and what moved is on the account rather than
  // in the reply, so the account is read back here instead of every caller
  // being left to remember that it has to be.
  Future<User> clearPicture() async {
    await _client.delete('$_root/me/image');

    return mine();
  }

  // A password that changed ends every token issued before it, this one
  // included, so the reply carries the replacement rather than the session
  // being dropped on the next call.
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    // Made through `renewing` because the server ends every other token as it
    // answers this: a poll already out is refused while this reply is still in
    // transit, and that refusal is about this call rather than about a session
    // that is over.
    final JsonMap body = await _client.renewing(
      () => _client.post(
        '/auth/change-password',
        body: <String, String>{
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'confirmNewPassword': confirmNewPassword,
        },
      ),
    );

    return AuthResult.fromJson(body).token;
  }

  static const String _root = '/users';
}
