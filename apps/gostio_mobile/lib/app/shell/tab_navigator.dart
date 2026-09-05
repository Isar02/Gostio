import 'package:flutter/material.dart';

import 'shell_tab.dart';

// One tab's own stack. A detail opened inside a tab is pushed here rather than
// over the shell, so the bar stays where the thumb left it and every tab keeps
// the history it was left in when the reader moved to another one.
class TabNavigator extends StatelessWidget {
  const TabNavigator({
    required this.tab,
    required this.navigatorKey,
    super.key,
  });

  final ShellTab tab;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (BuildContext context) => tab.root,
      ),
    );
  }
}
