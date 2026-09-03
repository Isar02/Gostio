import 'package:flutter/material.dart';

import 'app_section.dart';
import 'workspace_mode.dart';

sealed class NavigationEntry {
  const NavigationEntry();
}

// The label is the section's own unless the mode reads the same table from a
// narrower angle: a host's list is theirs, and saying so is the whole point.
final class NavigationLink extends NavigationEntry {
  NavigationLink(this.section, {String? label})
    : label = label ?? section.label;

  final AppSection section;
  final String label;
}

final class NavigationGroup extends NavigationEntry {
  NavigationGroup({
    required this.label,
    required this.icon,
    required this.links,
  });

  final String label;
  final IconData icon;
  final List<NavigationLink> links;
}

abstract final class AppNavigation {
  static List<NavigationEntry> forMode(WorkspaceMode mode) => switch (mode) {
    WorkspaceMode.administrator => _administrator,
    WorkspaceMode.host => _host,
  };

  static String labelFor(WorkspaceMode mode, AppSection section) {
    for (final NavigationEntry entry in forMode(mode)) {
      final String? label = switch (entry) {
        NavigationLink() => entry.section == section ? entry.label : null,
        NavigationGroup() => _labelIn(entry.links, section),
      };

      if (label != null) {
        return label;
      }
    }

    return section.label;
  }

  static String? _labelIn(List<NavigationLink> links, AppSection section) {
    for (final NavigationLink link in links) {
      if (link.section == section) {
        return link.label;
      }
    }

    return null;
  }

  static final List<NavigationEntry> _administrator = <NavigationEntry>[
    NavigationLink(AppSection.overview),
    NavigationLink(AppSection.accommodations),
    NavigationLink(AppSection.experiences),
    NavigationLink(AppSection.reservations),
    NavigationLink(AppSection.users),
    NavigationLink(AppSection.hostApplications),
    NavigationLink(AppSection.reviews),
    NavigationLink(AppSection.news),
    NavigationLink(AppSection.reports),
    NavigationGroup(
      label: 'Reference data',
      icon: Icons.dataset_outlined,
      links: <NavigationLink>[
        NavigationLink(AppSection.countries),
        NavigationLink(AppSection.cities),
        NavigationLink(AppSection.accommodationTypes),
        NavigationLink(AppSection.accommodationCategories),
        NavigationLink(AppSection.experienceCategories),
        NavigationLink(AppSection.amenities),
        NavigationLink(AppSection.roles),
        NavigationLink(AppSection.reservationStatuses),
      ],
    ),
    NavigationLink(AppSection.messages),
  ];

  static final List<NavigationEntry> _host = <NavigationEntry>[
    NavigationLink(AppSection.overview),
    NavigationLink(AppSection.accommodations, label: 'My accommodations'),
    NavigationLink(AppSection.experiences, label: 'My experiences'),
    NavigationLink(AppSection.reservations),
    NavigationLink(AppSection.reports),
    NavigationLink(AppSection.messages),
    NavigationLink(AppSection.profile),
  ];
}
