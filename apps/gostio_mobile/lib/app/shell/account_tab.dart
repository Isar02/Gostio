import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_metrics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';
import '../../features/auth/presentation/sign_out.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/notifications/data/push_registration.dart';
import '../../features/reviews/presentation/guest_reviews_screen.dart';
import 'tab_app_bar.dart';

// Who is signed in, what they have kept and written, and the way out. The
// account's picture, its details and its password are the profile screen's,
// and this tab holds the session seam until that screen exists.
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
            const SectionHeader('Saved'),
            _ProfileLink(
              title: 'Stays and experiences you have kept',
              message:
                  'Everything the heart on a listing has put aside, newest '
                  'first.',
              onTap: () => unawaited(FavoritesScreen.open(context)),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader('Reviews'),
            _ProfileLink(
              title: 'What you have written',
              message:
                  'The ratings you left on the stays and experiences you have '
                  'been on.',
              onTap: () =>
                  unawaited(GuestReviewsScreen.open(context, account.id)),
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              // A phone is handed between people, so this device gives up its
              // registration on the way out — while this account's token is
              // still what the call carries.
              onPressed: () => unawaited(
                signOut(
                  context,
                  beforeTokenEnds: context.read<PushRegistration>().forget,
                ),
              ),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

// One place this tab leads. The arrow is the only thing on it that is not
// words, because a row of a profile is read rather than scanned.
class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.title,
    required this.message,
    required this.onTap,
  });

  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      semanticLabel: '$title. $message',
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}
