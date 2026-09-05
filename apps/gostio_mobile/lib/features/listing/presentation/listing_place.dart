import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/listing_map.dart';
import '../../../core/widgets/section_header.dart';
import '../data/listing_detail.dart';
import 'listing_map_screen.dart';

// The screen the coordinates exist for. A guest deciding on a place is
// deciding on where it is, and an address without a map is a listing they
// leave in order to find out.
//
// The map here is a picture that opens a map: one inside a page that scrolls
// would take every drag that landed on it.
class ListingPlace extends StatelessWidget {
  const ListingPlace(this.detail, {super.key});

  final ListingDetail detail;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(switch (detail) {
          StayDetail() => 'Where you will be',
          ExperienceDetail() => 'Where you meet',
        }),
        Text(detail.where, style: text.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          detail.place,
          style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: AppRadii.medium,
          child: SizedBox(
            height: AppSizes.mapPreview,
            child: ListingMap(
              point: LatLng(detail.latitude, detail.longitude),
              onTap: () => ListingMapScreen.open(context, detail),
            ),
          ),
        ),
      ],
    );
  }
}
