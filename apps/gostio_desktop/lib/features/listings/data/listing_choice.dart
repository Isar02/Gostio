import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// A listing to narrow by, on the side of the catalogue it belongs to.
@immutable
class ListingChoice {
  const ListingChoice(this.kind, this.listing);

  // Places to stay first, as the navigation orders them.
  static List<ListingChoice> across({
    required List<LookupItem> accommodations,
    required List<LookupItem> experiences,
  }) => <ListingChoice>[
    for (final LookupItem stay in accommodations)
      ListingChoice(ListingKind.accommodation, stay),
    for (final LookupItem term in experiences)
      ListingChoice(ListingKind.experience, term),
  ];

  final ListingKind kind;
  final LookupItem listing;

  ListingAddress get address => ListingAddress(kind, listing.id);

  String get title => listing.name;

  @override
  bool operator ==(Object other) =>
      other is ListingChoice && other.kind == kind && other.listing == listing;

  @override
  int get hashCode => Object.hash(kind, listing);
}
