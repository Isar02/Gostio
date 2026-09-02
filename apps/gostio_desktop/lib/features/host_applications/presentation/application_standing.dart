import '../../../core/theme/tone.dart';
import '../data/host_application_status.dart';

// What a standing looks like on a chip. The label stays the API's own word for
// the row, so nothing here renames one; only the colour is decided.
abstract final class ApplicationStanding {
  static Tone toneOf(HostApplicationStatus? standing) => switch (standing) {
    HostApplicationStatus.pending => Tone.attention,
    HostApplicationStatus.approved => Tone.positive,
    HostApplicationStatus.rejected => Tone.negative,
    null => Tone.neutral,
  };
}
