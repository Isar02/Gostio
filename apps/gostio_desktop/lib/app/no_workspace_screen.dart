import 'package:flutter/material.dart';

import '../core/widgets/screen_states.dart';
import 'shell/sign_out.dart';

// The API lets a guest sign in; this client has nothing for one to do.
class NoWorkspaceScreen extends StatelessWidget {
  const NoWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        title: 'This account has no desktop workspace',
        message:
            'The desktop client serves administrators and hosts. Sign in with '
            'an account that holds one of those roles.',
        action: OutlinedButton(
          onPressed: () => signOut(context),
          child: const Text('Sign out'),
        ),
      ),
    );
  }
}
