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
// place until the deadline the server set. The hold is relative so that what
// the countdown prints is stable whenever the suite is run.
Reservation stayBooking({
  int id = 501,
  int guestCount = 2,
  DateTime? checkInDate,
  DateTime? checkOutDate,
  double accommodationTotal = 270,
  double cleaningFee = 15,
  Duration heldFor = const Duration(hours: 24),
  bool isPaid = false,
}) => _booking(
  id: id,
  guestCount: guestCount,
  totalPrice: accommodationTotal + cleaningFee,
  heldFor: heldFor,
  isPaid: isPaid,
  accommodationId: 1,
  checkInDate: checkInDate ?? DateTime(2026, 6, 12),
  checkOutDate: checkOutDate ?? DateTime(2026, 6, 15),
  accommodationTotal: accommodationTotal,
  cleaningFee: cleaningFee,
);

Reservation termBooking({
  int id = 502,
  int guestCount = 2,
  int experienceSlotId = 1,
  double pricePerPerson = 25,
  Duration heldFor = const Duration(hours: 24),
}) => _booking(
  id: id,
  guestCount: guestCount,
  totalPrice: pricePerPerson * guestCount,
  heldFor: heldFor,
  listingTitle: 'Old town walk',
  experienceId: 1,
  experienceSlotId: experienceSlotId,
  pricePerPerson: pricePerPerson,
);

Reservation _booking({
  required int id,
  required int guestCount,
  required double totalPrice,
  required Duration heldFor,
  bool isPaid = false,
  String listingTitle = 'Loft over the river',
  int? accommodationId,
  int? experienceId,
  int? experienceSlotId,
  DateTime? checkInDate,
  DateTime? checkOutDate,
  double? accommodationTotal,
  double? cleaningFee,
  double? pricePerPerson,
}) => Reservation(
  id: id,
  userId: 12,
  guestName: 'Emina Begić',
  listingTitle: listingTitle,
  guestCount: guestCount,
  reservationStatusId: 1,
  status: 'Pending',
  totalPrice: totalPrice,
  isPaid: isPaid,
  expiresAt: DateTime.now().toUtc().add(heldFor),
  createdAt: DateTime.now().toUtc(),
  accommodationId: accommodationId,
  experienceId: experienceId,
  experienceSlotId: experienceSlotId,
  checkInDate: checkInDate,
  checkOutDate: checkOutDate,
  accommodationTotal: accommodationTotal,
  cleaningFee: cleaningFee,
  pricePerPerson: pricePerPerson,
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
