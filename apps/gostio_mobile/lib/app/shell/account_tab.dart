import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';
import '../../features/auth/presentation/sign_out.dart';
import '../../features/reviews/presentation/guest_reviews_screen.dart';
import 'tab_app_bar.dart';

// Who is signed in, what they have written, and the way out. The account's
// picture, its details and what it has saved are the profile screen's, and
// this tab holds the session seam until that screen exists.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final User? account = context.select<Session, User?>(
      (Session session) => session.account,
    );

    // The session ends before this rebuilds, and for the frame in between
    // there is no account to draw.
    if (account == null) {
      return const Scaffold();
    }

    return Scaffold(
      appBar: const TabAppBar('Profile'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            const SectionHeader('Account'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(account.fullName, style: text.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    account.email,
                    style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    account.username,
                    style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader('Reviews'),
            AppCard(
              onTap: () =>
                  unawaited(GuestReviewsScreen.open(context, account.id)),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('What you have written', style: text.titleSmall),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'The ratings you left on the stays and experiences '
                          'you have been on.',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.inkFaint,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: () => signOut(context),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
