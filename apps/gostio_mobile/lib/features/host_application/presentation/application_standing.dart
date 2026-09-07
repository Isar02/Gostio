import 'package:gostio_core/gostio_core.dart';

// What a standing is called and coloured where the reader is the applicant
// rather than the administrator. `Pending`, `Approved` and `Rejected` are the
// words the API decides in; they are read on the other client by the person
// who does the deciding, and this one is read by the person waiting.
//
// A standing this build does not know keeps the server's own word for it and
// the neutral tone. The server is the authority on what a row is, and guessing
// a colour for a value that arrived after this build would be inventing one.
abstract final class ApplicationStanding {
  static String labelOf(HostApplication application) =>
      switch (application.standing) {
        HostApplicationStatus.pending => 'Waiting for an answer',
        HostApplicationStatus.approved => 'Approved',
        HostApplicationStatus.rejected => 'Turned down',
        null => application.status,
      };

  static Tone toneOf(HostApplication application) =>
      switch (application.standing) {
        HostApplicationStatus.pending => Tone.attention,
        HostApplicationStatus.approved => Tone.positive,
        HostApplicationStatus.rejected => Tone.negative,
        null => Tone.neutral,
      };

  // Whether the account may send another one. A request that was turned down
  // may be made again, and the server says so in the words it turns one down
  // with. It stays the server's decision: this only says whether the button is
  // worth offering.
  static bool canApplyAfter(HostApplication? application) =>
      application == null ||
      application.standing == HostApplicationStatus.rejected;
}
