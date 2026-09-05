import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';

// What both booking screens hold: how many people are coming, and the one
// write that turns what was chosen into a booking with a hold on it.
//
// What is being booked is the screen's own — a range of nights on one side, a
// term on the other — and it reaches this as a request that can be sent or as
// nothing at all. A screen with a choice still to make cannot describe a
// booking, so it is not offered one to send.
abstract class BookingNotifier extends ScreenNotifier {
  int _guestCount = 1;

  int get guestCount => _guestCount;

  // The largest party this booking could be for: what the place sleeps, or
  // what the term has left. A screen with nothing chosen yet answers one, so
  // the party is always a figure that could be sent.
  int get maximumGuests;

  bool get isBookable => !isBusy && pending != null;

  // Whether the reader has put anything into this screen: a party other than
  // the one it opened with, or a choice of what to book. Back asks before it
  // discards either of them.
  bool get hasInput => _guestCount != 1 || isChosen;

  String? get refusal => failure?.message;

  // Whether what is being booked has been picked out yet — a first night held
  // on the calendar, a term taken off the list.
  @protected
  bool get isChosen;

  @protected
  Future<Reservation> Function()? get pending;

  void setGuestCount(int count) {
    final int most = maximumGuests < 1 ? 1 : maximumGuests;
    final int held = count < 1 ? 1 : (count > most ? most : count);

    if (held == _guestCount) {
      return;
    }

    _guestCount = held;
    choiceChanged();
  }

  // What would be sent has changed. A refusal answered about something else no
  // longer describes anything on the screen, so it is dropped with the choice
  // it was about rather than left standing over a new one.
  @protected
  void choiceChanged() {
    clearFailure();
    publish();
  }

  // The booking that was made, or nothing where the server refused it. The
  // refusal is on the screen; the row is what the screen after it is drawn
  // from, so it is answered rather than kept.
  Future<Reservation?> book() async {
    final Future<Reservation> Function()? request = pending;
    if (request == null || isBusy) {
      return null;
    }

    Reservation? made;
    await performRequest(() async {
      made = await request();
    });

    return made;
  }
}
