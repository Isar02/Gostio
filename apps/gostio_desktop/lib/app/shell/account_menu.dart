import 'package:flutter/material.dart';

import '../../core/models/user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/account_avatar.dart';
import 'sign_out.dart';

class AccountMenu extends StatelessWidget {
  const AccountMenu({required this.account, super.key});

  final User account;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      itemBuilder: (BuildContext _) => <PopupMenuEntry<void>>[
        PopupMenuItem<void>(enabled: false, child: _Identity(account: account)),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: () => signOut(context),
          child: const Text('Sign out'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AccountAvatar(
              userId: account.id,
              name: account.fullName,
              hasImage: account.hasProfileImage,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              account.fullName,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Icon(Icons.expand_more, size: AppSizes.iconSmall),
          ],
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.account});

  final User account;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(account.fullName, style: text.titleSmall),
        Text(account.email, style: text.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          account.roles.join(' · '),
          style: text.labelSmall?.copyWith(color: AppColors.inkFaint),
        ),
      ],
    );
  }
}
