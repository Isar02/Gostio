import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../data/auth_repository.dart';

// The session ends whatever the server answered: a token it has already
// refused leaves the client in the state this call was going to produce.
Future<void> signOut(BuildContext context) async {
  final Session session = context.read<Session>();
  final AuthRepository repository = context.read<AuthRepository>();
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  try {
    await repository.signOut();
  } on ApiException catch (failure) {
    messenger.showSnackBar(SnackBar(content: Text(failure.message)));
  }

  session.end(SessionEnding.signedOut);
}
