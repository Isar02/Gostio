import '../../../core/formatting/app_dates.dart';
import '../../../core/formatting/app_numbers.dart';
import '../data/accommodation_availability.dart';

// The calendar says the same three things in a tooltip, on the bar under it
// and in the dialog that writes them, so they are written once.
abstract final class AvailabilityWords {
  static String span(DateTime from, DateTime to) => from == to
      ? AppDates.day(from)
      : '${AppDates.day(from)} to ${AppDates.day(to)}';

  static String nights(int count) =>
      '$count ${count == 1 ? 'night' : 'nights'}';

  static String entry(AccommodationAvailability entry) {
    final String days = span(entry.startDate, entry.endDate);

    if (!entry.isAvailable) {
      return 'Blocked · $days';
    }

    if (entry.priceOverride case final double price) {
      return '${AppNumbers.money(price)} a night · $days';
    }

    return 'Open · $days';
  }
}
