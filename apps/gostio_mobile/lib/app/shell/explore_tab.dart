import 'package:flutter/material.dart';

import '../../features/explore/presentation/explore_screen.dart';
import 'tab_app_bar.dart';

// The tab the client opens on. The screen under the bar is the explore
// feature's own and knows nothing of the shell, so this is where the two meet.
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: TabAppBar('Explore'),
      body: SafeArea(child: ExploreScreen()),
    );
  }
}
