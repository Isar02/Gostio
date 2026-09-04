import 'package:flutter/painting.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tone.dart';
import '../../reservations/data/reservation_status.dart';

// What a booking looks like wherever one is drawn. Three features report the
// same standing — the booking table, the calendar of one listing and the month
// laid across all of them — so the two answers are decided once, here, in the
// feature both catalogues already share for what they draw. The word beside
// either stays the API's own; only the colour is decided.
abstract final class BookingColours {
  // On a calendar a booking is a block of colour rather than a word, so it
  // takes a ground of its own. A standing this client does not know keeps the
  // neutral one: the server is the authority, and guessing on its behalf is
  // what this avoids.
  static Color bar(ReservationStatus? standing) => switch (standing) {
    ReservationStatus.confirmed => AppColors.indigo,
    ReservationStatus.pending => AppColors.warning,
    _ => AppColors.neutral,
  };

  // In a table or a list it is ink on a ground instead, which is a different
  // question and reads a different colour: confirmed is the calendar's indigo
  // and a chip's green.
  static Tone tone(ReservationStatus? standing) => switch (standing) {
    ReservationStatus.pending => Tone.attention,
    ReservationStatus.confirmed => Tone.positive,
    ReservationStatus.cancelled => Tone.negative,
    ReservationStatus.completed => Tone.informative,
    null => Tone.neutral,
  };
}
