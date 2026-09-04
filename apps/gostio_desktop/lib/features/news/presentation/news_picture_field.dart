import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/api_image.dart';

// The picture an article is published with. One that has been chosen is drawn
// from the bytes in hand rather than from the server, which has not been sent
// them yet.
class NewsPictureField extends StatelessWidget {
  const NewsPictureField({
    required this.chosen,
    required this.storedPath,
    required this.isBusy,
    required this.onChoose,
    this.onKeepStored,
    this.errorText,
    super.key,
  });

  final ImageUpload? chosen;
  final String? storedPath;
  final bool isBusy;
  final VoidCallback onChoose;
  final VoidCallback? onKeepStored;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Picture', style: text.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        _Frame(chosen: chosen, storedPath: storedPath),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: isBusy ? null : onChoose,
              icon: const Icon(Icons.image_outlined, size: AppSizes.iconSmall),
              label: Text(_chooseLabel),
            ),
            if (onKeepStored case final VoidCallback keep) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: isBusy ? null : keep,
                child: const Text('Keep the stored one'),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          errorText ?? _footnote,
          style: text.bodySmall?.copyWith(
            color: errorText == null ? AppColors.inkFaint : AppColors.danger,
          ),
        ),
      ],
    );
  }

  String get _chooseLabel {
    if (chosen != null) {
      return 'Choose another';
    }

    return storedPath == null ? 'Choose a picture' : 'Replace the picture';
  }

  String get _footnote => switch (chosen) {
    final ImageUpload picked =>
      '${picked.name} · ${AppNumbers.size(picked.bytes.length)}',
    null =>
      'JPEG, PNG or WebP, at most '
          '${ImageRules.maximumBytes ~/ (1024 * 1024)} MB. '
          '${storedPath == null ? 'An article is published with one.' : 'The stored one stays until another is chosen.'}',
  };
}

class _Frame extends StatelessWidget {
  const _Frame({required this.chosen, required this.storedPath});

  final ImageUpload? chosen;
  final String? storedPath;

  @override
  Widget build(BuildContext context) {
    final Widget picture = switch (chosen) {
      final ImageUpload picked => Image.memory(
        picked.bytes,
        fit: BoxFit.cover,
        width: double.infinity,
      ),
      null => ApiImage(
        path: storedPath,
        borderRadius: BorderRadius.zero,
        width: double.infinity,
      ),
    };

    return Container(
      height: AppSizes.photoCoverHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.neutralGround,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border, width: AppSizes.hairline),
      ),
      child: picture,
    );
  }
}
