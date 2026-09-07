import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_sheet.dart';

// What the reader may do with the picture on their account. Taking one and
// choosing one are two different acts on a phone, so both are offered rather
// than one file dialogue standing for both.
enum PictureAct { camera, gallery, remove }

abstract final class ProfilePictureSheet {
  static Future<PictureAct?> show(
    BuildContext context, {
    required bool hasPicture,
  }) => AppSheet.show<PictureAct>(
    context,
    title: hasPicture ? 'Your picture' : 'Add a picture',
    builder: (BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Act(label: 'Take a photo', act: PictureAct.camera),
        _Act(label: 'Choose from your gallery', act: PictureAct.gallery),
        if (hasPicture)
          _Act(
            label: 'Remove your picture',
            act: PictureAct.remove,
            isDestructive: true,
          ),
      ],
    ),
  );
}

class _Act extends StatelessWidget {
  const _Act({
    required this.label,
    required this.act,
    this.isDestructive = false,
  });

  final String label;
  final PictureAct act;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: AppSizes.touchTarget,
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: isDestructive ? AppColors.danger : AppColors.ink),
      ),
      onTap: () => Navigator.of(context).pop(act),
    );
  }
}
