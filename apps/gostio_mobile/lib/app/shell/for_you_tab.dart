import 'package:flutter/material.dart';

import '../../features/recommendations/presentation/for_you_screen.dart';
import 'tab_app_bar.dart';

// What the server suggests to whoever is signed in. The screen under the bar
// is the recommendations feature's own and knows nothing of the shell, so this
// is where the two meet.
class ForYouTab extends StatelessWidget {
  const ForYouTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: TabAppBar('For you'),
      body: SafeArea(child: ForYouScreen()),
    );
  }
}
