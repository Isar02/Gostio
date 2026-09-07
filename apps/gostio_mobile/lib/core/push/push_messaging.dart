import 'push_notice.dart';

// The phone's side of push delivery, behind one interface so that exactly one
// file in this client imports the messaging package. Everything written
// against this — registering a device, asking to be allowed to draw a notice,
// answering a tap — is tested over a double with no service behind it.
//
// A device that has no messaging service configured answers no token and no
// permission rather than throwing: push is a delivery of a row that was
// written either way, so a client without it is a client that reads its
// notices when it is opened.
abstract interface class PushMessaging {
  // The identifier this device is reached at, or nothing where the service is
  // not configured or could not be started.
  Future<String?> deviceToken();

  // The service rotates a token on reinstall, on a restore to a new device and
  // on its own schedule. A client that registers once and never listens goes
  // quiet without ever failing.
  Stream<String> get deviceTokenChanges;

  // Asked at the moment there is something to be notified about rather than on
  // the first frame, where the only honest answer is no. Asking again after it
  // has been answered returns that answer without troubling the reader.
  Future<void> askToDrawNotices();

  // A delivery that arrived while the reader is in the application. No system
  // notice is drawn over a screen they are already looking at; what it is worth
  // is the count and the list being current.
  Stream<PushNotice> get arrivals;

  // A notice the reader tapped, whether the application was behind it or shut.
  // A tap that arrived before anything was listening is held for the first
  // reader rather than dropped, because a client started by a tap starts after
  // the tap happened.
  Stream<PushNotice> get opened;

  Future<void> close();
}
