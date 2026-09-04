import '../../../core/theme/tone.dart';

// A charge and a refund each name their own state, and the two enumerations
// share every name this colours. One it does not know keeps the word, not a
// tone. It is the payment's standing rather than the booking's, which is why
// it is not decided beside that one.
abstract final class SettlementTone {
  static Tone of(String status) => switch (status.toLowerCase()) {
    'succeeded' => Tone.positive,
    'pending' => Tone.attention,
    'cancelled' || 'failed' => Tone.negative,
    _ => Tone.neutral,
  };
}
