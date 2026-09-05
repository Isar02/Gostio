import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// A filter in force, and the same query with it taken off. A chip carries the
// query it would leave behind rather than a field name the row would have to
// know how to unset, so one chip row serves both catalogues.
@immutable
class AppliedFilter<TQuery> {
  const AppliedFilter(this.label, this.without);

  final String label;
  final TQuery without;
}

// What a catalogue's filters answer to the screen above them. The two
// catalogues share no field — a stay has amenities and guests, a term has
// places and a length — so what they have in common is said here as behaviour
// rather than as a set of columns neither of them really has.
abstract interface class ListingFilters<TSelf extends ListingFilters<TSelf>> {
  // The words in the field above the results. They are not one of the chips:
  // they are already on the screen, in the place they were typed.
  String? get title;

  List<AppliedFilter<TSelf>> get applied;

  JsonMap toParameters();

  TSelf searchingFor(String? title);

  // Everything the sheet set, dropped. The words stay: clearing the filters
  // and emptying the field are two different gestures.
  TSelf get cleared;
}

// Telling "leave this as it was" from "take this off" needs a third value,
// because the second one is null.
const Object unchanged = Object();

T? carried<T>(Object? given, T? current) =>
    identical(given, unchanged) ? current : given as T?;

String? written(String? value) {
  final String? trimmed = value?.trim();

  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

// A band is one chip whichever of its ends were given, and both queries say it
// the same way, so neither of them holds its own copy of the sentence.
String? priceLabel(double? least, double? most) => switch ((least, most)) {
  (final double from, final double to) =>
    '${AppNumbers.money(from)} to ${AppNumbers.money(to)}',
  (final double from, null) => 'From ${AppNumbers.money(from)}',
  (null, final double to) => 'Up to ${AppNumbers.money(to)}',
  _ => null,
};
