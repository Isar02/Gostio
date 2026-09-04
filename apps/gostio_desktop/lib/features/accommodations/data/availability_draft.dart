import 'package:gostio_core/gostio_core.dart';

// What the calendar writes, in the two shapes the server accepts. A range that
// stays open carries a nightly price of its own and a blocked one carries
// none, so the pair is written as two constructors rather than as a flag and a
// nullable figure that can disagree with it.
class AvailabilityDraft {
  const AvailabilityDraft.open({
    required this.startDate,
    required this.endDate,
    required double price,
  }) : isAvailable = true,
       priceOverride = price;

  const AvailabilityDraft.blocked({
    required this.startDate,
    required this.endDate,
  }) : isAvailable = false,
       priceOverride = null;

  static const String priceField = 'priceOverride';

  final DateTime startDate;
  final DateTime endDate;
  final bool isAvailable;
  final double? priceOverride;

  JsonMap toJson() => <String, dynamic>{
    'startDate': CalendarDays.write(startDate),
    'endDate': CalendarDays.write(endDate),
    'isAvailable': isAvailable,
    'priceOverride': priceOverride,
  };
}
