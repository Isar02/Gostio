import 'package:gostio_core/gostio_core.dart';

import '../data/booking_repository.dart';
import 'booking_notifier.dart';

// A term being taken: which one, and how many places on it. The party is held
// to what the term has left, so choosing a smaller term trims it rather than
// leaving a figure the server is about to refuse.
class TermBookingNotifier extends BookingNotifier {
  TermBookingNotifier(this._repository, this.experience);

  final BookingRepository _repository;
  final Experience experience;

  ExperienceSlot? _chosen;

  ExperienceSlot? get chosen => _chosen;

  // The price a head is the experience's and is only multiplied out. Nothing
  // is charged from this figure: the server prices the booking again.
  double get total => experience.pricePerPerson * guestCount;

  // A term that has not been chosen offers no step, which is one place rather
  // than none: a stepper drawn over an empty range would have no value to sit
  // between its two buttons.
  @override
  int get maximumGuests => _chosen?.remainingCapacity ?? 1;

  @override
  bool get isChosen => _chosen != null;

  @override
  Future<Reservation> Function()? get pending {
    final ExperienceSlot? chosen = _chosen;

    return chosen == null
        ? null
        : () => _repository.bookTerm(slotId: chosen.id, guestCount: guestCount);
  }

  void choose(ExperienceSlot term) {
    _chosen = term;
    setGuestCount(guestCount);
    choiceChanged();
  }
}
