import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../features/auth/presentation/sign_out.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/host_application/presentation/host_application_screen.dart';
import '../../features/notifications/data/push_registration.dart';
import '../../features/profile/presentation/profile_link.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reviews/presentation/guest_reviews_screen.dart';
import 'tab_app_bar.dart';

// Who is signed in, and everything an account reaches from itself. The profile
// draws the account and writes it; where the other rows lead is named here,
// because the features they open are neither the profile's business nor each
// other's.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final User? account = context.select<Session, User?>(
      (Session session) => session.account,
    );
    final bool hosts = context.select<Session, bool>(
      (Session session) => session.isHost,
    );

    // The session ends before this rebuilds, and for the frame in between
    // there is no account to draw.
    if (account == null) {
      return const Scaffold();
    }

    return Scaffold(
      appBar: const TabAppBar('Profile'),
      body: SafeArea(
        child: ProfileScreen(
          account: account,
          links: <ProfileLink>[
            ProfileLink(
              title: 'Stays and experiences you have kept',
              message:
                  'Everything the heart on a listing has put aside, newest '
                  'first.',
              onTap: () => unawaited(FavoritesScreen.open(context)),
            ),
            // Where an application stands is the screen's answer rather
            // than this row's: reading one costs a request, and every profile
            // would pay it to caption a door. The role is already in hand and
            // is enough to name what is behind it.
            ProfileLink(
              title: hosts ? 'Hosting on Gostio' : 'Become a host',
              message: hosts
                  ? 'Your account is verified. Listings and their bookings '
                        'are managed in the desktop application.'
                  : 'Put a place or an experience of your own up, and take '
                        'bookings against it.',
              onTap: () => unawaited(HostApplicationScreen.open(context)),
            ),
            ProfileLink(
              title: 'What you have written',
              message:
                  'The ratings you left on the stays and experiences you have '
                  'been on.',
              onTap: () =>
                  unawaited(GuestReviewsScreen.open(context, account.id)),
            ),
          ],
          // A phone is handed between people, so this device gives up its
          // registration on the way out — while this account's token is still
          // what the call carries.
          onSignOut: () => unawaited(
            signOut(
              context,
              beforeTokenEnds: context.read<PushRegistration>().forget,
            ),
          ),
        ),
      ),
    );
  }
}
