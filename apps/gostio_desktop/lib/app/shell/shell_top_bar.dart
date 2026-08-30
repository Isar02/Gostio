import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import 'account_menu.dart';
import 'workspace.dart';
import 'workspace_switch.dart';

class ShellTopBar extends StatelessWidget {
  const ShellTopBar({required this.account, super.key});

  final User account;

  @override
  Widget build(BuildContext context) {
    final Workspace workspace = context.watch<Workspace>();

    return Container(
      height: AppSizes.topBar,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: AppSizes.hairline),
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            workspace.sectionLabel,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          if (workspace.canSwitchMode) ...<Widget>[
            WorkspaceSwitch(workspace: workspace),
            const SizedBox(width: AppSpacing.md),
          ],
          AccountMenu(account: account),
        ],
      ),
    );
  }
}
