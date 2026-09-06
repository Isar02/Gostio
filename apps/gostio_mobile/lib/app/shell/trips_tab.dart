import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../features/trips/presentation/trips_screen.dart';
import '../reviewed_trip_screen.dart';
import 'tab_app_bar.dart';

// The bookings this account has made. Who is signed in is the shell's to know,
// so the screen under the bar is handed a guest and asks the server for that
// guest's own bookings — a host reading this tab sees what they booked rather
// than what was booked from them.
class TripsTab extends StatelessWidget {
  const TripsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final User? account = context.select<Session, User?>(
      (Session session) => session.account,
    );

    // The session ends before this rebuilds, and for the frame in between
    // there is no account whose trips these are.
    if (account == null) {
      return const Scaffold();
    }

    return Scaffold(
      appBar: const TabAppBar('Trips'),
      body: SafeArea(
        child: TripsScreen(
          guestId: account.id,
          openTrip: ReviewedTripScreen.open,
        ),
      ),
    );
  }
}
