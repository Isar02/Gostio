import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/section_header.dart';
import '../data/picture_source.dart';
import '../data/profile_repository.dart';
import 'profile_details_screen.dart';
import 'profile_identity.dart';
import 'profile_link.dart';
import 'profile_notifier.dart';
import 'profile_password_screen.dart';
import 'profile_write_lock.dart';

// The account, and the three things it may write about itself. Who is signed
// in is the session's answer, so this screen is handed that account rather than
// reading one of its own: what a write puts back into the session is what the
// rest of the client draws, and there is one copy of it rather than two.
//
// Where else the profile leads is the caller's to say. The saved listings and
// the reviews are other features' screens, and the layer that composes them is
// the one that already knows about both.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.account,
    required this.onSignOut,
    this.links = const <ProfileLink>[],
    super.key,
  });

  final User account;
  final VoidCallback onSignOut;
  final List<ProfileLink> links;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileNotifier>(
      create: (BuildContext context) {
        final ProfileNotifier profile = ProfileNotifier(
          context.read<ProfileRepository>(),
          context.read<PictureSource>(),
          context.read<Session>(),
          context.read<ProfileWriteLock>(),
        );
        // The account on this session was answered when the token was issued,
        // which may have been days ago on a phone that has stayed signed in.
        unawaited(profile.refresh());

        return profile;
      },
      child: _Profile(account: account, onSignOut: onSignOut, links: links),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({
    required this.account,
    required this.onSignOut,
    required this.links,
  });

  final User account;
  final VoidCallback onSignOut;
  final List<ProfileLink> links;

  @override
  Widget build(BuildContext context) {
    final ProfileNotifier profile = context.watch<ProfileNotifier>();

    return RefreshIndicator(
      onRefresh: profile.refresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          // A refused read leaves what is on the screen standing: it is the
          // account this session signed in as, which is older rather than
          // wrong.
          if (profile.refreshFailureMessage case final String message) ...[
            AppNotice(message, tone: Tone.attention),
            const SizedBox(height: AppSpacing.lg),
          ],
          ProfileIdentity(account: account),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader('Account'),
          AppCard(
            child: Column(
              children: <Widget>[
                _Fact(label: 'Email', value: account.email),
                const SizedBox(height: AppSpacing.md),
                _Fact(
                  label: 'Phone',
                  value: account.phoneNumber ?? 'Not given',
                ),
                const SizedBox(height: AppSpacing.md),
                _Fact(label: 'Joined', value: AppDates.date(account.createdAt)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ProfileLink(
            title: 'Your details',
            message: profile.isRefreshing
                ? 'Refreshing your latest details before they can be edited.'
                : 'Your name, your email, and the number a host reaches you on.',
            onTap: profile.isRefreshing
                ? null
                : () => unawaited(ProfileDetailsScreen.open(context, account)),
          ),
          const SizedBox(height: AppSpacing.md),
          ProfileLink(
            title: 'Password',
            message: 'Change the password you sign in with.',
            onTap: () => unawaited(ProfilePasswordScreen.open(context)),
          ),
          for (final ProfileLink link in links) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            link,
          ],
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton(onPressed: onSignOut, child: const Text('Sign out')),
        ],
      ),
    );
  }
}

// One thing the account says about itself, read as a pair rather than as a
// sentence: the label is what it is, and the value is what it says.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: text.bodySmall?.copyWith(color: AppColors.inkFaint)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: text.bodyMedium,
          ),
        ),
      ],
    );
  }
}
