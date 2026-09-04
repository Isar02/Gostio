import 'package:json_annotation/json_annotation.dart';

part 'accommodation_availability.g.dart';

// The calendar is open where no entry covers it, so a listing answers with its
// exceptions rather than with a year of days. Both bounds are the server's and
// both are inclusive: two entries sharing a single day overlap, and one ending
// the day before the next begins does not.
@JsonSerializable(createToJson: false)
class AccommodationAvailability {
  const AccommodationAvailability({
    required this.id,
    required this.accommodationId,
    required this.startDate,
    required this.endDate,
    required this.isAvailable,
    this.priceOverride,
  });

  factory AccommodationAvailability.fromJson(Map<String, dynamic> json) =>
      _$AccommodationAvailabilityFromJson(json);

  final int id;
  final int accommodationId;
  final DateTime startDate;
  final DateTime endDate;
  final bool isAvailable;
  final double? priceOverride;

  bool covers(DateTime day) =>
      !day.isBefore(startDate) && !day.isAfter(endDate);

  bool overlaps({required DateTime from, required DateTime to}) =>
      !startDate.isAfter(to) && !from.isAfter(endDate);
}
