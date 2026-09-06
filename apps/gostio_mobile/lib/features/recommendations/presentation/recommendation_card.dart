import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/widgets/listing_card.dart';
import '../../listing/presentation/listing_screen.dart';
import 'recommendation_reasons.dart';

// One suggestion, and why it is one. The facts are the same facts every other
// card in this client draws; what is added under the rule is the reasoning,
// which is the only thing this screen has that Explore does not.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard(this.picked, {super.key});

  final Recommendation picked;

  @override
  Widget build(BuildContext context) {
    return ListingCard(
      title: picked.title,
      place: '${picked.cityName}, ${picked.countryName}',
      price: picked.price,
      priceUnit: switch (picked.target) {
        ListingKind.accommodation => 'per night',
        ListingKind.experience => 'per person',
      },
      coverPath: picked.coverPath,
      rating: picked.averageRating,
      reviewCount: picked.reviewCount,
      status: picked.categoryName,
      notes: reasonsInWords(picked),
      onTap: () => ListingScreen.open(context, picked.listing),
    );
  }
}
