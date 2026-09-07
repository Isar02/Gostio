import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../data/auth_repository.dart';

// The session ends whatever the server answered: a token it has already
// refused leaves the client in the state this call was going to produce.
//
// Anything that has to be given up while this account's token still works goes
// in `beforeTokenEnds`. It runs after everything this needs has been read, so
// the session ends whether or not the screen that asked for it is still there
// — a sign-out the reader pressed is not one to abandon halfway.
Future<void> signOut(
  BuildContext context, {
  Future<void> Function()? beforeTokenEnds,
}) async {
  final Session session = context.read<Session>();
  final AuthRepository repository = context.read<AuthRepository>();
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  await beforeTokenEnds?.call();

  try {
    await repository.signOut();
  } on ApiException catch (failure) {
    messenger.showSnackBar(SnackBar(content: Text(failure.message)));
  }

  session.end(SessionEnding.signedOut);
}
