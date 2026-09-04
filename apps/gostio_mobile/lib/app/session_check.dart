import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../features/auth/data/auth_repository.dart';

// A token can die while the application is in the background, and the phone
// gives no sign of it. Coming back to the foreground asks the server who is
// signed in: a refusal ends the session there and then rather than on the
// next tap, and anything else is left alone.
class SessionCheck extends StatefulWidget {
  const SessionCheck({required this.child, super.key});

  final Widget child;

  @override
  State<SessionCheck> createState() => _SessionCheckState();
}

class _SessionCheckState extends State<SessionCheck>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_askWhoIsSignedIn());
    }
  }

  Future<void> _askWhoIsSignedIn() async {
    final Session session = context.read<Session>();
    if (!session.isSignedIn) {
      return;
    }

    try {
      // A 401 ends the session through the client; what comes back instead is
      // the account as it stands, which may have been edited elsewhere.
      session.accountChanged(await context.read<AuthRepository>().me());
    } on ApiException {
      return;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
