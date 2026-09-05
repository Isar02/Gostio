import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../core/widgets/discard_guard.dart';
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

  final Map<ShellTab, _StackDepth> _depths = <ShellTab, _StackDepth>{
    for (final ShellTab tab in ShellTab.values) tab: _StackDepth(),
  };

  ShellTab _current = ShellTab.first;

  // The answer a route is waiting to give while a tab is being emptied.
  Completer<bool>? _answer;

  @override
  void dispose() {
    _stopWaiting(isLeaving: false);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _back();
        }
      },
      child: NotificationListener<DiscardAnswered>(
        // A route that refused a pop answers here rather than to the call that
        // asked, because the call was told the same thing either way.
        onNotification: (DiscardAnswered answered) {
          _stopWaiting(isLeaving: answered.isLeaving);

          return false;
        },
        child: Scaffold(
          body: IndexedStack(
            index: _current.index,
            children: <Widget>[
              for (final ShellTab tab in ShellTab.values)
                TabNavigator(
                  tab: tab,
                  navigatorKey: _navigators[tab]!,
                  observers: <NavigatorObserver>[_depths[tab]!],
                ),
            ],
          ),
          bottomNavigationBar: _Bar(current: _current, onChosen: _choose),
        ),
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

    unawaited(_toRootOf(chosen));
  }

  // The stack is emptied one route at a time and each one is asked rather than
  // told. Emptying it in a single call would pop past a route that still holds
  // something the reader has not applied — the same answer Back leaves it, made
  // by a different gesture.
  //
  // A route that answers with a question waits here for the reader to answer
  // it. Yes carries on down the stack, because the reader asked for the top of
  // this tab and one route agreeing to go was not the whole of that. No stops
  // the gesture, and what is left standing is what they chose to keep.
  Future<void> _toRootOf(ShellTab tab) async {
    final NavigatorState? navigator = _navigators[tab]?.currentState;
    final _StackDepth depth = _depths[tab]!;

    _stopWaiting(isLeaving: false);

    while (navigator != null && navigator.mounted && navigator.canPop()) {
      final int before = depth.routes;
      await navigator.maybePop();

      if (!navigator.mounted) {
        return;
      }

      if (depth.routes < before) {
        continue;
      }

      final Completer<bool> answer = Completer<bool>();
      _answer = answer;

      if (!await answer.future) {
        return;
      }
    }
  }

  void _stopWaiting({required bool isLeaving}) {
    final Completer<bool>? answer = _answer;
    _answer = null;

    if (answer != null && !answer.isCompleted) {
      answer.complete(isLeaving);
    }
  }

  // Back is answered here because a tab is a stack of its own. It leaves the
  // screen first, then the tab, and only the first tab's own route hands the
  // gesture back to the system, which is what closes the client.
  //
  // The tab is asked rather than told. A screen or a sheet inside it may still
  // hold something the reader has not applied, and answering this gesture with
  // a question of its own is a route's to make; popping it from out here would
  // take that answer away from every one of them.
  void _back() {
    final NavigatorState? navigator = _navigators[_current]?.currentState;
    if (navigator != null && navigator.canPop()) {
      unawaited(navigator.maybePop());

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

// How many routes a tab is holding. The shell needs this to tell a route that
// left from one that refused: both answer `maybePop` the same way, and only
// the stack itself says which of the two happened.
class _StackDepth extends NavigatorObserver {
  int routes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => routes++;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => routes--;

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes--;
}
