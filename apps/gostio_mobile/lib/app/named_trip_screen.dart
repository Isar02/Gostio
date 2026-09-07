import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../core/widgets/screen_states.dart';
import '../features/trips/data/trips_repository.dart';
import '../features/trips/presentation/named_trip_notifier.dart';
import 'reviewed_trip_screen.dart';

// The booking a notice names, opened from the bell's list or from a delivered
// notice the reader tapped. A notice carries an id and nothing else, so the
// row is read here and the trip is drawn over it once it has landed.
//
// It stands between two features and belongs to neither, which is why it is
// here: the notice is one feature's, the trip is another's, and the review
// under a finished trip is a third's.
class NamedTripScreen extends StatelessWidget {
  const NamedTripScreen(this.reservationId, {super.key});

  static Future<void> open(BuildContext context, int reservationId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => NamedTripScreen(reservationId),
        ),
      );

  final int reservationId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NamedTripNotifier>(
      create: (BuildContext context) =>
          NamedTripNotifier(context.read<TripsRepository>(), reservationId),
      child: const _NamedTrip(),
    );
  }
}

class _NamedTrip extends StatelessWidget {
  const _NamedTrip();

  @override
  Widget build(BuildContext context) {
    final NamedTripNotifier trip = context.watch<NamedTripNotifier>();
    final Reservation? booking = trip.booking;

    if (booking != null) {
      return ReviewedTripScreen(booking, onChanged: trip.accept);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trip')),
      body: SafeArea(
        child: trip.isLoading
            ? const LoadingState()
            : ErrorState(
                message:
                    trip.failureMessage ?? 'This booking could not be read.',
                traceId: trip.failureTraceId,
                onRetry: trip.load,
              ),
      ),
    );
  }
}
