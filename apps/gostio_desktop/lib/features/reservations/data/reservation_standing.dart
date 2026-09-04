import '../../../core/theme/tone.dart';
import 'reservation_status.dart';

// What a standing looks like on a chip. It sits beside the standing rather
// than beside the table, because the overview reports a booking too and the
// two must not disagree about what a colour means. The label stays the API's own word for
// the row, so nothing here renames a status; only the colour is decided.
abstract final class ReservationStanding {
  static Tone toneOf(ReservationStatus? standing) => switch (standing) {
    ReservationStatus.pending => Tone.attention,
    ReservationStatus.confirmed => Tone.positive,
    ReservationStatus.cancelled => Tone.negative,
    ReservationStatus.completed => Tone.informative,
    null => Tone.neutral,
  };

  // A charge and a refund name their own state, and the two enumerations share
  // every name this colours. One it does not know keeps the word, not a tone.
  static Tone toneOfSettlement(String status) => switch (status.toLowerCase()) {
    'succeeded' => Tone.positive,
    'pending' => Tone.attention,
    'cancelled' || 'failed' => Tone.negative,
    _ => Tone.neutral,
  };
}
