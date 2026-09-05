import 'package:flutter/material.dart';

import '../../core/theme/app_metrics.dart';
import '../../features/notifications/presentation/notification_bell.dart';

// The bar over a tab's own screen. A screen pushed inside a tab builds its own
// bar with its own arrow; this one is for the route a tab opens on, which has
// nothing behind it to go back to.
//
// The bell is here rather than in each tab so that there is one of it however
// many tabs the reader moves through.
class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TabAppBar(this.title, {super.key});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.appBar);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      automaticallyImplyLeading: false,
      actions: const <Widget>[NotificationBell()],
    );
  }
}
