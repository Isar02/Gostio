import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/listing_map.dart';
import '../data/listing_detail.dart';

// The map the preview on the listing opens. This is the one that is driven,
// which is why it is a screen: a map the reader may pan needs the drag the
// page under the preview was using to scroll.
class ListingMapScreen extends StatelessWidget {
  const ListingMapScreen(this.detail, {super.key});

  static Future<void> open(BuildContext context, ListingDetail detail) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => ListingMapScreen(detail),
        ),
      );

  final ListingDetail detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(detail.title)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListingMap(
              point: LatLng(detail.latitude, detail.longitude),
              isInteractive: true,
            ),
          ),
          _Footer(detail),
        ],
      ),
    );
  }
}

// What the pin is standing on, and the way to the licence the tiles are drawn
// under. The credit itself is on the map; this is the control that leads to
// what it credits, drawn where a thumb has room to hit it.
class _Footer extends StatelessWidget {
  const _Footer(this.detail);

  final ListingDetail detail;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(detail.where, style: text.titleSmall),
                  Text(
                    detail.place,
                    style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _openLicence(context),
              child: const Text('Map data'),
            ),
          ],
        ),
      ),
    );
  }

  // The licence is a page in a browser, and a device without one is a device
  // this cannot reach. It is said rather than thrown: the map is still drawn
  // and still credited on the tiles.
  Future<void> _openLicence(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    bool opened = false;

    try {
      opened = await launchUrl(
        mapLicence,
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      opened = false;
    }

    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing here can open $mapCredit.')),
      );
    }
  }
}
