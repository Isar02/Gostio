import 'package:flutter/painting.dart';

import '../../../core/theme/app_colors.dart';
import '../../reservations/data/reservation_status.dart';

// What a booking looks like where it is a block of colour rather than a word:
// on the calendar of one listing, and on the month laid across all of them. A
// chip in a table is coloured by its tone instead, which is a ground behind
// ink rather than a bar; a standing this client does not know keeps neither.
abstract final class BookingColours {
  static Color bar(ReservationStatus? standing) => switch (standing) {
    ReservationStatus.confirmed => AppColors.indigo,
    ReservationStatus.pending => AppColors.warning,
    _ => AppColors.neutral,
  };
}
