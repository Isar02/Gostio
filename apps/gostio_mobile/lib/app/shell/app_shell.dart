import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gostio_core/gostio_core.dart';

import 'shell_tab.dart';
import 'tab_navigator.dart';

// What an account is in. Five tabs over five navigators, and the bar under all
// of them: the tab a detail was opened from is the tab it is read in, and the
// bar it was opened from is still there when it closes.
//
// The tabs are kept rather than rebuilt, so a list scrolled halfway is where it
// was left when the reader comes back to it.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final Map<ShellTab, GlobalKey<NavigatorState>> _navigators =
      <ShellTab, GlobalKey<NavigatorState>>{
        for (final ShellTab tab in ShellTab.values)
          tab: GlobalKey<NavigatorState>(),
      };

  ShellTab _current = ShellTab.first;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _back();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _current.index,
          children: <Widget>[
            for (final ShellTab tab in ShellTab.values)
              TabNavigator(tab: tab, navigatorKey: _navigators[tab]!),
          ],
        ),
        bottomNavigationBar: _Bar(current: _current, onChosen: _choose),
      ),
    );
  }

  // Choosing the tab that is already open is a way back to the top of it,
  // which is the only gesture a phone has for a stack several screens deep.
  void _choose(ShellTab chosen) {
    if (chosen != _current) {
      setState(() => _current = chosen);

      return;
    }

    _navigators[chosen]?.currentState?.popUntil(
      (Route<dynamic> route) => route.isFirst,
    );
  }

  // Back is answered here because a tab is a stack of its own. It leaves the
  // screen first, then the tab, and only the first tab's own route hands the
  // gesture back to the system, which is what closes the client.
  void _back() {
    final NavigatorState? navigator = _navigators[_current]?.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();

      return;
    }

    if (_current != ShellTab.first) {
      setState(() => _current = ShellTab.first);

      return;
    }

    unawaited(SystemNavigator.pop());
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.current, required this.onChosen});

  final ShellTab current;
  final void Function(ShellTab tab) onChosen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // The bar is told from the screen above it by a line rather than by a
      // shadow, which is the same edge every other surface here carries.
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: NavigationBar(
        selectedIndex: current.index,
        onDestinationSelected: (int index) => onChosen(ShellTab.values[index]),
        destinations: <Widget>[
          for (final ShellTab tab in ShellTab.values)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
