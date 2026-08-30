import 'package:flutter/foundation.dart';

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

  bool get isAdministrator => hasRole(RoleNames.administrator);

  bool get isHost => hasRole(RoleNames.host);

  bool hasRole(String role) => _account?.hasRole(role) ?? false;

  void begin({required User account, required String token}) {
    _account = account;
    _lastEnding = null;
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

    notifyListeners();
  }

  @override
  void dispose() {
    _client.onUnauthorized = null;

    super.dispose();
  }
}
