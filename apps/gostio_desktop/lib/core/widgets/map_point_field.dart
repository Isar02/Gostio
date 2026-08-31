import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

// Coordinates are chosen on a map rather than typed. The tile policy asks
// callers to identify themselves and to credit the map where it is drawn,
// with the credit leading to the licence.
const String _tiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String _identity = 'ba.gostio.desktop';
const String _credit = '© OpenStreetMap contributors';
final Uri _licence = Uri.parse('https://www.openstreetmap.org/copyright');

// Every city in this catalogue is in Bosnia and Herzegovina, so a listing with
// no point of its own opens over the country rather than over the ocean.
const LatLng _countryCentre = LatLng(43.9159, 17.6791);
const double _countryZoom = 7;
const double _pointZoom = 14;

class MapPointField extends StatelessWidget {
  const MapPointField({
    required this.point,
    required this.onChanged,
    this.label = 'Coordinates',
    this.errorText,
    super.key,
  });

  final LatLng? point;
  final ValueChanged<LatLng> onChanged;
  final String label;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final LatLng? point = this.point;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              point == null ? 'Not chosen' : _written(point),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: point == null ? AppColors.inkFaint : AppColors.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _choose(context),
            child: Text(point == null ? 'Choose on map' : 'Move'),
          ),
        ],
      ),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final LatLng? chosen = await showDialog<LatLng>(
      context: context,
      builder: (BuildContext context) => _MapPicker(point: point),
    );

    if (chosen != null) {
      onChanged(chosen);
    }
  }

  static String _written(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, '
      '${point.longitude.toStringAsFixed(5)}';
}

class _MapPicker extends StatefulWidget {
  const _MapPicker({this.point});

  final LatLng? point;

  @override
  State<_MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<_MapPicker> {
  late LatLng? _point = widget.point;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text('Choose the place', style: text.titleLarge),
      content: SizedBox(
        width: AppSizes.mapDialog,
        height: AppSizes.mapDialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Click the map to put the pin where the listing is.',
              style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ClipRRect(
                borderRadius: AppRadii.medium,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _point ?? _countryCentre,
                    initialZoom: _point == null ? _countryZoom : _pointZoom,
                    onTap: (TapPosition _, LatLng point) =>
                        setState(() => _point = point),
                  ),
                  children: <Widget>[
                    TileLayer(
                      urlTemplate: _tiles,
                      userAgentPackageName: _identity,
                    ),
                    if (_point case final LatLng point)
                      MarkerLayer(
                        markers: <Marker>[
                          Marker(
                            point: point,
                            child: const Icon(
                              Icons.place,
                              color: AppColors.indigo,
                            ),
                          ),
                        ],
                      ),
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: _Credit(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _point == null
                  ? 'No point chosen yet.'
                  : MapPointField._written(_point!),
              style: text.bodySmall,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _point == null
              ? null
              : () => Navigator.of(context).pop(_point),
          child: const Text('Use this place'),
        ),
      ],
    );
  }
}

class _Credit extends StatelessWidget {
  const _Credit();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: AppRadii.small,
        child: InkWell(
          onTap: () => launchUrl(_licence),
          borderRadius: AppRadii.small,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              _credit,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.indigo,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
