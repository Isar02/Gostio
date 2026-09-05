import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/listing_card.dart';
import '../../listing/presentation/favorite_edits.dart';
import '../../listing/presentation/listing_screen.dart';

// One row of either catalogue, opening the listing it stands for. Each is a
// widget rather than a closure inside the results list, because the heart it
// draws is watched per card: a list that watched it as a whole would redraw
// every row each time one of them was saved, and the framework refuses that
// watch inside a sliver for exactly that reason.
class StayCard extends StatelessWidget {
  const StayCard(this.stay, {super.key});

  final Accommodation stay;

  @override
  Widget build(BuildContext context) {
    final ListingAddress address = ListingAddress(
      ListingKind.accommodation,
      stay.id,
    );

    return ListingCard(
      title: stay.title,
      place: '${stay.cityName}, ${stay.countryName}',
      price: stay.pricePerNight,
      priceUnit: 'per night',
      coverPath: stay.coverPath,
      rating: stay.averageRating,
      reviewCount: stay.reviewCount,
      status: stay.accommodationTypeName,
      isFavorite: _isSaved(context, address, stay.isFavorite),
      onTap: () => ListingScreen.open(context, address),
    );
  }
}

class TermCard extends StatelessWidget {
  const TermCard(this.term, {super.key});

  final Experience term;

  @override
  Widget build(BuildContext context) {
    final ListingAddress address = ListingAddress(
      ListingKind.experience,
      term.id,
    );

    return ListingCard(
      title: term.title,
      place: '${term.cityName}, ${term.countryName}',
      price: term.pricePerPerson,
      priceUnit: 'per person',
      coverPath: term.coverPath,
      rating: term.averageRating,
      reviewCount: term.reviewCount,
      status: AppDurations.inWords(term.durationMinutes),
      isFavorite: _isSaved(context, address, term.isFavorite),
      onTap: () => ListingScreen.open(context, address),
    );
  }
}

// A card says what the server answered when its page arrived, unless this
// reader has since turned the heart on the listing's own screen.
bool _isSaved(BuildContext context, ListingAddress address, bool asRead) =>
    context.select<FavoriteEdits, bool?>(
      (FavoriteEdits edits) => edits.of(address),
    ) ??
    asRead;
