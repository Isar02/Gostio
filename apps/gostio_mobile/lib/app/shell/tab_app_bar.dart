import 'package:flutter/material.dart';

import '../../core/theme/app_metrics.dart';

// The bar over a tab's own screen. A screen pushed inside a tab builds its own
// bar with its own arrow; this one is for the route a tab opens on, which has
// nothing behind it to go back to.
class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TabAppBar(this.title, {super.key});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.appBar);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title), automaticallyImplyLeading: false);
  }
}
