import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../features/messages/presentation/inbox_screen.dart';
import 'tab_app_bar.dart';

// The threads this account is in. Who is signed in is the shell's to know, so
// the screen under the bar is handed a reader: which side of a thread is
// theirs decides what every row and every line on it says.
class InboxTab extends StatelessWidget {
  const InboxTab({super.key});

  @override
  Widget build(BuildContext context) {
    final User? account = context.select<Session, User?>(
      (Session session) => session.account,
    );

    // The session ends before this rebuilds, and for the frame in between
    // there is nobody whose threads these are.
    if (account == null) {
      return const Scaffold();
    }

    return Scaffold(
      appBar: const TabAppBar('Inbox'),
      body: SafeArea(child: InboxScreen(callerId: account.id)),
    );
  }
}
