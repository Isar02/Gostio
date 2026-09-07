import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_metrics.dart';
import '../../core/widgets/count_badge.dart';
import '../../features/messages/presentation/unread_messages.dart';
import 'shell_tab.dart';

// The five destinations under every tab stack. The inbox icon carries what is
// waiting because this is the stable route back to those messages.
class ShellBar extends StatelessWidget {
  const ShellBar({required this.current, required this.onChosen, super.key});

  final ShellTab current;
  final void Function(ShellTab tab) onChosen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: NavigationBar(
        selectedIndex: current.index,
        onDestinationSelected: (int index) => onChosen(ShellTab.values[index]),
        destinations: <Widget>[
          for (final ShellTab tab in ShellTab.values)
            NavigationDestination(
              icon: _Destination(tab: tab, icon: tab.icon),
              selectedIcon: _Destination(tab: tab, icon: tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({required this.tab, required this.icon});

  final ShellTab tab;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (tab != ShellTab.inbox) {
      return Icon(icon);
    }

    final int unread = context.select<UnreadMessages, int>(
      (UnreadMessages messages) => messages.unread,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Icon(icon),
        if (unread > 0)
          Positioned(
            top: -AppSpacing.sm,
            right: -AppSpacing.sm,
            child: CountBadge(unread),
          ),
      ],
    );
  }
}
