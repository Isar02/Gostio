import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../authorization/role_names.dart';
import '../models/user.dart';
import '../network/api_client.dart';

enum SessionEnding { signedOut, tokenDied }

class Session extends ChangeNotifier {
  Session(this._client) {
    _client.onUnauthorized = () => end(SessionEnding.tokenDied);
  }

  final ApiClient _client;

  User? _account;
  SessionEnding? _lastEnding;

  User? get account => _account;

  SessionEnding? get lastEnding => _lastEnding;

  bool get isSignedIn => _account != null;

  int get tokenGeneration => _client.tokenGeneration;

  bool get isAdministrator => hasRole(RoleNames.administrator);

  bool get isHost => hasRole(RoleNames.host);

  bool hasRole(String role) => _account?.hasRole(role) ?? false;

  void begin({required User account, required String token}) {
    _account = account;
    _lastEnding = null;
    _client.token = token;

    notifyListeners();
  }

  // Editing the profile answers the account the rest of the client is drawing
  // from, so the top bar is not left showing the name that was just replaced.
  void accountChanged(User account) {
    if (_account == null) {
      return;
    }

    _account = account;

    notifyListeners();
  }

  // Changing a password ends every token issued before it, the one this
  // session holds included, so the replacement has to be taken up here or the
  // next call is answered with a 401.
  void tokenRenewed(String token) {
    if (_account == null) {
      return;
    }

    _client.token = token;

    notifyListeners();
  }

  void end(SessionEnding ending) {
    if (_account == null) {
      return;
    }

    _account = null;
    _lastEnding = ending;
    _client.token = null;
    PaintingBinding.instance.imageCache.clear();

    notifyListeners();
  }

  @override
  void dispose() {
    _client.onUnauthorized = null;

    super.dispose();
  }
}
