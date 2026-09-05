import 'package:gostio_core/gostio_core.dart';

// A term of an experience the way the API answers one. The places left are the
// server's own count, so a test says what it wants left rather than adding up
// bookings of its own.
ExperienceSlot experienceSlot({
  int id = 1,
  int experienceId = 1,
  DateTime? startTime,
  int durationMinutes = 180,
  int capacity = 8,
  int remainingCapacity = 8,
  bool isActive = true,
}) {
  final DateTime begins = startTime ?? DateTime.utc(2026, 7, 14, 9);

  return ExperienceSlot(
    id: id,
    experienceId: experienceId,
    startTime: begins,
    endTime: begins.add(Duration(minutes: durationMinutes)),
    durationMinutes: durationMinutes,
    capacity: capacity,
    remainingCapacity: remainingCapacity,
    isActive: isActive,
  );
}

// A booking as it comes back from the create: pending, unpaid and holding its
// place until the deadline the server set. Both the hold and the nights are
// relative, so what the screen says about either is the same whenever the
// suite is run and a booking is never one the reader has already been on.
Reservation stayBooking({
  int id = 501,
  int guestCount = 2,
  DateTime? checkInDate,
  DateTime? checkOutDate,
  double accommodationTotal = 270,
  double cleaningFee = 15,
  Duration heldFor = const Duration(hours: 24),
  bool isPaid = false,
  ReservationStatus standing = ReservationStatus.pending,
}) {
  final DateTime arrival =
      checkInDate ?? CalendarDays.addDays(CalendarDays.today(), 30);

  return _booking(
    id: id,
    guestCount: guestCount,
    totalPrice: accommodationTotal + cleaningFee,
    heldFor: heldFor,
    isPaid: isPaid,
    standing: standing,
    accommodationId: 1,
    checkInDate: arrival,
    checkOutDate: checkOutDate ?? CalendarDays.addDays(arrival, 3),
    accommodationTotal: accommodationTotal,
    cleaningFee: cleaningFee,
  );
}

Reservation termBooking({
  int id = 502,
  int guestCount = 2,
  int experienceSlotId = 1,
  double pricePerPerson = 25,
  Duration heldFor = const Duration(hours: 24),
  bool isPaid = false,
  ReservationStatus standing = ReservationStatus.pending,
  DateTime? startTime,
}) => _booking(
  id: id,
  guestCount: guestCount,
  totalPrice: pricePerPerson * guestCount,
  heldFor: heldFor,
  isPaid: isPaid,
  standing: standing,
  listingTitle: 'Old town walk',
  experienceId: 1,
  experienceSlotId: experienceSlotId,
  experienceSlotStartTime:
      startTime ?? DateTime.now().toUtc().add(const Duration(days: 20)),
  pricePerPerson: pricePerPerson,
);

Reservation _booking({
  required int id,
  required int guestCount,
  required double totalPrice,
  required Duration heldFor,
  bool isPaid = false,
  ReservationStatus standing = ReservationStatus.pending,
  String listingTitle = 'Loft over the river',
  int? accommodationId,
  int? experienceId,
  int? experienceSlotId,
  DateTime? checkInDate,
  DateTime? checkOutDate,
  DateTime? experienceSlotStartTime,
  double? accommodationTotal,
  double? cleaningFee,
  double? pricePerPerson,
}) => Reservation(
  id: id,
  userId: 12,
  guestName: 'Emina Begić',
  listingTitle: listingTitle,
  guestCount: guestCount,
  reservationStatusId: _keyOf(standing),
  status: _wordFor(standing),
  totalPrice: totalPrice,
  isPaid: isPaid,
  expiresAt: DateTime.now().toUtc().add(heldFor),
  createdAt: DateTime.now().toUtc(),
  accommodationId: accommodationId,
  experienceId: experienceId,
  experienceSlotId: experienceSlotId,
  checkInDate: checkInDate,
  checkOutDate: checkOutDate,
  experienceSlotStartTime: experienceSlotStartTime,
  accommodationTotal: accommodationTotal,
  cleaningFee: cleaningFee,
  pricePerPerson: pricePerPerson,
);

// The seeded key the API files a standing under, and the word it answers
// beside it.
int _keyOf(ReservationStatus standing) => switch (standing) {
  ReservationStatus.pending => 1,
  ReservationStatus.confirmed => 2,
  ReservationStatus.cancelled => 3,
  ReservationStatus.completed => 4,
};

String _wordFor(ReservationStatus standing) => switch (standing) {
  ReservationStatus.pending => 'Pending',
  ReservationStatus.confirmed => 'Confirmed',
  ReservationStatus.cancelled => 'Cancelled',
  ReservationStatus.completed => 'Completed',
};

// What calling a booking off would send back, as the server quotes it.
RefundQuote owedBack({
  int reservationId = 501,
  bool isPaid = true,
  double charged = 285,
  double amount = 285,
  int percentage = 100,
  String reason = 'Cancelled inside the free grace period.',
}) => RefundQuote(
  reservationId: reservationId,
  isPaid: isPaid,
  charged: charged,
  currency: 'bam',
  percentage: percentage,
  amount: amount,
  reason: reason,
  graceEndsAt: DateTime.now().toUtc().add(const Duration(hours: 20)),
  asOf: DateTime.now().toUtc(),
);

// A charge as the create answers one: open, and carrying the pair a card sheet
// is opened with. A charge that is read rather than started answers neither.
ReservationPayment openCharge({
  int reservationId = 501,
  double amount = 285,
  String? clientSecret = 'pi_1_secret_9',
  String? publishableKey = 'pk_test_9',
}) => ReservationPayment(
  id: 90,
  reservationId: reservationId,
  status: 'Pending',
  amount: amount,
  currency: 'bam',
  clientSecret: clientSecret,
  publishableKey: publishableKey,
  createdAt: DateTime.now().toUtc(),
);
