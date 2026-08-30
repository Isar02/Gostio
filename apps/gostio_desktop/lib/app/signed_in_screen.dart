import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/user.dart';
import '../core/network/api_exception.dart';
import '../core/session/session.dart';
import '../core/theme/app_metrics.dart';
import '../features/auth/data/auth_repository.dart';

class SignedInScreen extends StatelessWidget {
  const SignedInScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    final User? account = context.select<Session, User?>(
      (Session s) => s.account,
    );
    if (account == null) {
      return const Scaffold();
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              account.fullName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(account.username),
            const SizedBox(height: AppSpacing.lg),
            Text(account.roles.join(', ')),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: () => _signOut(context),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
