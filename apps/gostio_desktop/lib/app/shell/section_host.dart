import 'package:flutter/material.dart';

import '../../core/models/user.dart';
import 'app_section.dart';
import 'section_screen.dart';
import 'workspace_mode.dart';

// The content region carries a navigator of its own so a detail screen pushes
// over its list while the navigation and the top bar stay where they are. The
// key restarts that stack on every move, including the switch between modes:
// the two read the same tables from different angles.
class SectionHost extends StatelessWidget {
  const SectionHost({
    required this.mode,
    required this.section,
    required this.account,
    super.key,
  });

  final WorkspaceMode mode;
  final AppSection section;
  final User account;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: ValueKey<(WorkspaceMode, AppSection)>((mode, section)),
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (BuildContext context) =>
            SectionScreen(mode: mode, section: section, account: account),
      ),
    );
  }
}
