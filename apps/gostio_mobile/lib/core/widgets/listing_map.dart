import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_metrics.dart';

// Where a listing is, drawn rather than named. This client only ever shows a
// point; choosing one is the host's gesture and it is made on the desktop.
//
// The tile policy asks callers to identify themselves and to credit the map
// where it is drawn. The credit is written here, on every map; the licence it
// leads to is a control, so it is offered where there is room for one a thumb
// can hit rather than as small print over the tiles.
const String mapCredit = '© OpenStreetMap contributors';
final Uri mapLicence = Uri.parse('https://www.openstreetmap.org/copyright');

const String _tiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String _identity = 'ba.gostio.mobile';
const double _pointZoom = 15;

class ListingMap extends StatelessWidget {
  const ListingMap({
    required this.point,
    this.isInteractive = false,
    this.onTap,
    super.key,
  });

  final LatLng point;

  // A map inside a page that scrolls takes every drag that lands on it and
  // leaves the reader stuck against it. So the one on a listing is a picture
  // that opens a map, and only the map it opens is driven.
  final bool isInteractive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget map = FlutterMap(
      options: MapOptions(
        initialCenter: point,
        initialZoom: _pointZoom,
        interactionOptions: InteractionOptions(
          flags: isInteractive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: <Widget>[
        TileLayer(urlTemplate: _tiles, userAgentPackageName: _identity),
        MarkerLayer(
          markers: <Marker>[
            Marker(
              point: point,
              child: const Icon(
                Icons.place,
                color: AppColors.indigo,
                size: AppSizes.icon,
              ),
            ),
          ],
        ),
      ],
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(child: isInteractive ? map : IgnorePointer(child: map)),
        if (onTap case final VoidCallback onTap)
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Open the map',
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
          ),
        const Align(alignment: Alignment.bottomRight, child: _Credit()),
      ],
    );
  }
}

class _Credit extends StatelessWidget {
  const _Credit();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: AppRadii.small,
      ),
      child: Text(mapCredit, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
