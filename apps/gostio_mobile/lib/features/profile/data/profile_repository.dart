import 'package:gostio_core/gostio_core.dart';

import 'password_draft.dart';
import 'profile_draft.dart';

// The account the token belongs to. Not one route here names an id: who is
// asking is the token's answer, and an id the client could type would make
// this the administrator's endpoint under another name.
class ProfileRepository {
  const ProfileRepository(this._client);

  static const String fileField = 'File';

  final ApiClient _client;

  Future<User> mine() async => User.fromJson(await _client.get('$_root/me'));

  Future<User> update(ProfileDraft draft) async =>
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
  //
  // The replacement is taken up inside the guard rather than after it. The two
  // thirty second polls this client runs are refused from the moment the server
  // raises the account's token version, and they go on being refused until this
  // client holds the new token — so the guard has to cover the reply being read
  // and adopted as well as the call itself. `adopt` runs in that window, which
  // is why it is handed in rather than left to the caller to do afterwards.
  Future<void> changePassword(
    PasswordDraft draft, {
    required void Function(String token) adopt,
  }) => _client.renewing(() async {
    final JsonMap body = await _client.post(
      '/auth/change-password',
      body: draft.toChange(),
    );

    adopt(AuthResult.fromJson(body).token);
  });

  static const String _root = '/users';
}
