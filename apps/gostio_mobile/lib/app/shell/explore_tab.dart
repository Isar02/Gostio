import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/explore/presentation/explore_screen.dart';
import '../../features/news/data/news_repository.dart';
import '../../features/news/presentation/news_notifier.dart';
import '../../features/news/presentation/news_strip.dart';
import 'tab_app_bar.dart';

// The tab the client opens on. The screen under the bar is the explore
// feature's own and knows nothing of the shell, so this is where the two meet
// — and where the news over its results is composed, because what the platform
// publishes is a third feature's and neither of the other two should know it.
//
// The strip is read once for the tab rather than once per catalogue: it is
// drawn over both of them and they are both alive at once.
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NewsNotifier>(
      create: (BuildContext context) =>
          NewsNotifier(context.read<NewsRepository>()),
      child: const Scaffold(
        appBar: TabAppBar('Explore'),
        body: SafeArea(child: ExploreScreen(resultsHeader: NewsStrip())),
      ),
    );
  }
}
