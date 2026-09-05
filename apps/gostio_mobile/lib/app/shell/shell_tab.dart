import 'package:flutter/material.dart';

import 'account_tab.dart';
import 'pending_tab.dart';

// The five places this client is read in, and what each one opens on. A tab is
// a destination in the bar and the first route of its own navigator, so the
// two are named together rather than in a list the bar and the stack could
// disagree about.
enum ShellTab {
  explore('Explore', Icons.search_outlined, Icons.search_rounded),
  forYou('For you', Icons.auto_awesome_outlined, Icons.auto_awesome_rounded),
  trips('Trips', Icons.luggage_outlined, Icons.luggage_rounded),
  inbox('Inbox', Icons.forum_outlined, Icons.forum_rounded),
  profile('Profile', Icons.person_outline_rounded, Icons.person_rounded);

  const ShellTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  // The first tab, which is where the client opens and where Back leaves it.
  static ShellTab get first => explore;

  Widget get root => switch (this) {
    ShellTab.explore => const PendingTab(
      tab: ShellTab.explore,
      title: 'Stays and experiences',
      message: 'The two catalogues and the search over them open in this tab.',
    ),
    ShellTab.forYou => const PendingTab(
      tab: ShellTab.forYou,
      title: 'Picked for you',
      message:
          'Listings chosen from what you have booked and saved open in this '
          'tab, each with the reasons it was picked.',
    ),
    ShellTab.trips => const PendingTab(
      tab: ShellTab.trips,
      title: 'Your bookings',
      message:
          'Bookings you have made open in this tab, with their dates, their '
          'status and what has been paid.',
    ),
    ShellTab.inbox => const PendingTab(
      tab: ShellTab.inbox,
      title: 'Messages',
      message: 'Conversations with hosts and with support open in this tab.',
    ),
    ShellTab.profile => const AccountTab(),
  };
}
