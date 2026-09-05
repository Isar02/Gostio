import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/section_header.dart';

// What a stay comes with. They are the same pills the filter sheet offers,
// because a reader who narrowed a search by Wi-Fi should recognise the word
// they chose in the listing they opened.
class ListingAmenities extends StatelessWidget {
  const ListingAmenities(this.amenities, {super.key});

  final List<LookupItem> amenities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader('What this place offers'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final LookupItem amenity in amenities) AppChip(amenity.name),
          ],
        ),
      ],
    );
  }
}
