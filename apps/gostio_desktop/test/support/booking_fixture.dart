import 'package:gostio_desktop/features/reservations/data/reservation.dart';

// A stay, which is the shape most of these tests read. What a test is actually
// about it names itself; everything else is a plausible row from the seed.
Reservation booking({
  int id = 1,
  int reservationStatusId = 1,
  String status = 'Pending',
  bool isPaid = false,
  int? accommodationId = 4,
  int? experienceId,
  int? experienceSlotId,
  DateTime? checkInDate,
  DateTime? checkOutDate,
  double? accommodationTotal = 720,
  double? cleaningFee = 40,
  double? pricePerPerson,
}) => Reservation(
  id: id,
  userId: 21,
  guestName: 'Ana Marić',
  listingTitle: 'Stone villa on the hill above Neum',
  guestCount: 4,
  reservationStatusId: reservationStatusId,
  status: status,
  totalPrice: 760,
  isPaid: isPaid,
  expiresAt: DateTime.utc(2026, 9, 3, 12),
  createdAt: DateTime.utc(2026, 8, 20, 9, 30),
  accommodationId: accommodationId,
  experienceId: experienceId,
  experienceSlotId: experienceSlotId,
  checkInDate: checkInDate ?? DateTime(2026, 9, 12),
  checkOutDate: checkOutDate ?? DateTime(2026, 9, 16),
  accommodationTotal: accommodationTotal,
  cleaningFee: cleaningFee,
  pricePerPerson: pricePerPerson,
);

// A term is booked against a slot and carries no dates of its own.
Reservation termBooking({
  int reservationStatusId = 2,
  String status = 'Confirmed',
  bool isPaid = true,
}) => Reservation(
  id: 2,
  userId: 21,
  guestName: 'Ana Marić',
  listingTitle: 'Rafting the Neretva canyon',
  guestCount: 2,
  reservationStatusId: reservationStatusId,
  status: status,
  totalPrice: 170,
  isPaid: isPaid,
  expiresAt: DateTime.utc(2026, 9, 3, 12),
  createdAt: DateTime.utc(2026, 8, 21, 8),
  experienceId: 12,
  experienceSlotId: 33,
  pricePerPerson: 85,
);
