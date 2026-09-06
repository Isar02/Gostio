import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/widgets/listing_card.dart';
import '../../listing/presentation/listing_screen.dart';

// One kept listing. Every row on this screen is saved, so no heart is drawn on
// any of them; what a row does say is which catalogue it came from, because
// the two are read here in one list.
class FavoriteCard extends StatelessWidget {
  const FavoriteCard(this.saved, {super.key});

  final Favorite saved;

  @override
  Widget build(BuildContext context) {
    return ListingCard(
      title: saved.listingTitle,
      place: '${saved.cityName}, ${saved.countryName}',
      price: saved.price,
      priceUnit: _unit,
      coverPath: saved.coverPath,
      status: _standing,
      statusTone: saved.isListingActive ? Tone.neutral : Tone.attention,
      onTap: _opening(context),
    );
  }

  // What the price is per, which is the one figure on this card the two
  // catalogues disagree about.
  String? get _unit => switch (saved.listing?.kind) {
    ListingKind.accommodation => 'per night',
    ListingKind.experience => 'per person',
    null => null,
  };

  // Which catalogue the row came from, because the two are read here in one
  // list. A row this client cannot address says nothing rather than a word it
  // would have had to guess.
  String? get _standing => saved.isListingActive
      ? switch (saved.listing?.kind) {
          ListingKind.accommodation => 'Stay',
          ListingKind.experience => 'Experience',
          null => null,
        }
      : 'No longer listed';

  // A listing its host has withdrawn stays in this list and stops being a way
  // in: the API answers a guest 404 for it, so the row says it has gone rather
  // than opening a screen that cannot be read.
  VoidCallback? _opening(BuildContext context) {
    if (!saved.isListingActive) {
      return null;
    }

    return switch (saved.listing) {
      final ListingAddress address => () => ListingScreen.open(
        context,
        address,
      ),
      null => null,
    };
  }
}
