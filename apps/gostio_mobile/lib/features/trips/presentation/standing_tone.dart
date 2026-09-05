import 'package:gostio_core/gostio_core.dart';

// What a booking's standing looks like wherever one is read: in the list and
// on the screen the list opens. The word beside the colour stays the API's
// own, and a standing this client does not know keeps the neutral one — the
// server is the authority, and guessing on its behalf is what this avoids.
abstract final class StandingTone {
  static Tone of(ReservationStatus? standing) => switch (standing) {
    ReservationStatus.pending => Tone.attention,
    ReservationStatus.confirmed => Tone.positive,
    ReservationStatus.cancelled => Tone.negative,
    ReservationStatus.completed => Tone.informative,
    null => Tone.neutral,
  };
}
