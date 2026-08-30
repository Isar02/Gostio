import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import 'app_navigation.dart';
import 'app_section.dart';
import 'workspace.dart';
import 'workspace_mode.dart';

class ShellNavigation extends StatefulWidget {
  const ShellNavigation({super.key});

  @override
  State<ShellNavigation> createState() => _ShellNavigationState();
}

class _ShellNavigationState extends State<ShellNavigation> {
  final Set<NavigationGroup> _expanded = <NavigationGroup>{};

  void _toggle(NavigationGroup group) {
    setState(() {
      if (!_expanded.remove(group)) {
        _expanded.add(group);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Workspace workspace = context.watch<Workspace>();

    return Material(
      color: AppColors.surface,
      child: Container(
        width: AppSizes.navigation,
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(
              color: AppColors.border,
              width: AppSizes.hairline,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Brand(mode: workspace.mode),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.sm),
                children: <Widget>[
                  for (final NavigationEntry entry in workspace.navigation)
                    switch (entry) {
                      NavigationLink() => _Link(
                        link: entry,
                        isSelected: entry.section == workspace.section,
                        onOpen: workspace.open,
                      ),
                      NavigationGroup() => _Group(
                        group: entry,
                        selected: workspace.section,
                        isExpanded:
                            _expanded.contains(entry) ||
                            _holds(entry, workspace.section),
                        onToggle: () => _toggle(entry),
                        onOpen: workspace.open,
                      ),
                    },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _holds(NavigationGroup group, AppSection section) =>
      group.links.any((NavigationLink link) => link.section == section);
}

class _Brand extends StatelessWidget {
  const _Brand({required this.mode});

  final WorkspaceMode mode;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SizedBox(
      height: AppSizes.topBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Gostio',
              style: text.titleLarge?.copyWith(color: AppColors.indigoDeep),
            ),
            Text(mode.panelName, style: text.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({
    required this.link,
    required this.isSelected,
    required this.onOpen,
    this.isNested = false,
  });

  final NavigationLink link;
  final bool isSelected;
  final ValueChanged<AppSection> onOpen;
  final bool isNested;

  @override
  Widget build(BuildContext context) {
    return _Row(
      label: link.label,
      icon: link.section.icon,
      isSelected: isSelected,
      isNested: isNested,
      onTap: () => onOpen(link.section),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.selected,
    required this.isExpanded,
    required this.onToggle,
    required this.onOpen,
  });

  final NavigationGroup group;
  final AppSection selected;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<AppSection> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Row(
          label: group.label,
          icon: group.icon,
          isSelected: false,
          onTap: onToggle,
          trailing: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            size: AppSizes.iconSmall,
          ),
        ),
        if (isExpanded)
          for (final NavigationLink link in group.links)
            _Link(
              link: link,
              isSelected: link.section == selected,
              onOpen: onOpen,
              isNested: true,
            ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isNested = false,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isNested;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color foreground = isSelected
        ? AppColors.indigoDeep
        : AppColors.inkMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Ink(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.selected : null,
          borderRadius: AppRadii.medium,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.medium,
          hoverColor: AppColors.hover,
          child: Container(
            height: AppSizes.control,
            padding: EdgeInsets.only(
              left: isNested ? AppSpacing.xl : AppSpacing.md,
              right: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: AppSizes.iconSmall, color: foreground),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected ? AppColors.indigoDeep : AppColors.ink,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (trailing case final Widget trailing) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
