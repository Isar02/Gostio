import 'package:flutter/material.dart';

import '../../core/widgets/screen_states.dart';
import 'shell_tab.dart';
import 'tab_app_bar.dart';

// A tab that is reachable before what it holds has been built. It says what
// opens there rather than drawing an empty screen the reader has to guess at.
class PendingTab extends StatelessWidget {
  const PendingTab({
    required this.tab,
    required this.title,
    required this.message,
    super.key,
  });

  final ShellTab tab;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TabAppBar(tab.label),
      body: SafeArea(
        child: EmptyState(title: title, message: message, icon: tab.icon),
      ),
    );
  }
}
