import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../features/reviews/data/reviews_repository.dart';
import '../features/reviews/presentation/booking_review.dart';
import '../features/reviews/presentation/booking_review_notifier.dart';
import '../features/trips/presentation/trip_screen.dart';

// The application composes the two features that meet on a completed trip.
// Neither feature needs to reach into the other's presentation layer.
class ReviewedTripScreen extends StatelessWidget {
  const ReviewedTripScreen(this.booking, {this.onChanged, super.key});

  static Future<void> open(
    BuildContext context,
    Reservation booking,
    ValueChanged<Reservation> onChanged,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          ReviewedTripScreen(booking, onChanged: onChanged),
    ),
  );

  final Reservation booking;
  final ValueChanged<Reservation>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (booking.standing != ReservationStatus.completed) {
      return TripScreen(booking, onChanged: onChanged);
    }

    return ChangeNotifierProvider<BookingReviewNotifier>(
      create: (BuildContext context) =>
          BookingReviewNotifier(context.read<ReviewsRepository>(), booking.id),
      child: TripScreen(
        booking,
        onChanged: onChanged,
        completedContent: BookingReview(listingTitle: booking.listingTitle),
      ),
    );
  }
}
