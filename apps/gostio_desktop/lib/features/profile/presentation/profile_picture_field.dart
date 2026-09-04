import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/confirmation_dialog.dart';

// A picture is written the moment it is chosen rather than waiting on a Save
// beside it: it has an endpoint of its own, and a form that saved the fields
// but not the picture standing under them would be the worse surprise.
class ProfilePictureField extends StatefulWidget {
  const ProfilePictureField({
    required this.account,
    required this.isBusy,
    required this.onChosen,
    required this.onCleared,
    this.errorText,
    super.key,
  });

  final User account;
  final bool isBusy;
  final ValueChanged<ImageUpload> onChosen;
  final VoidCallback onCleared;
  final String? errorText;

  @override
  State<ProfilePictureField> createState() => _ProfilePictureFieldState();
}

class _ProfilePictureFieldState extends State<ProfilePictureField> {
  String? _fault;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? said = _fault ?? widget.errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AccountAvatar(
          userId: widget.account.id,
          name: widget.account.fullName,
          hasImage: widget.account.hasProfileImage,
          size: AppSizes.avatarLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: widget.isBusy ? null : _choose,
              icon: const Icon(Icons.image_outlined, size: AppSizes.iconSmall),
              label: Text(
                widget.account.hasProfileImage
                    ? 'Replace picture'
                    : 'Choose a picture',
              ),
            ),
            if (widget.account.hasProfileImage) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: widget.isBusy ? null : _confirmRemove,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Remove'),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          said ?? _footnote,
          style: text.bodySmall?.copyWith(
            color: said == null ? AppColors.inkFaint : AppColors.danger,
          ),
        ),
      ],
    );
  }

  String get _footnote =>
      'JPEG, PNG or WebP, at most '
      '${ImageRules.maximumBytes ~/ (1024 * 1024)} MB. It stands beside your '
      'listings and your messages.';

  Future<void> _choose() async {
    final List<PlatformFile> chosen = await FilePicker.pickFiles(
      dialogTitle: 'Choose a picture',
      type: FileType.custom,
      allowedExtensions: ImageRules.extensions,
    );

    if (chosen.isEmpty) {
      return;
    }

    ImageUpload picked;

    try {
      picked = ImageUpload(
        name: chosen.first.name,
        bytes: await chosen.first.readAsBytes(),
      );
    } on Exception catch (failure) {
      if (mounted) {
        setState(() => _fault = 'That file could not be read. $failure');
      }

      return;
    }

    // Refused here rather than sent and refused: the bytes are read either
    // way, and the server's own sentence for this is the one shown.
    final String? refusal = picked.refusal;

    if (!mounted) {
      return;
    }

    setState(() => _fault = refusal);

    if (refusal == null) {
      widget.onChosen(picked);
    }
  }

  Future<void> _confirmRemove() async {
    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Remove your picture?',
      message:
          'Your initials stand in its place until another one is chosen. The '
          'picture itself is gone.',
      confirmLabel: 'Remove picture',
      isDestructive: true,
    );

    if (!agreed) {
      return;
    }

    setState(() => _fault = null);

    widget.onCleared();
  }
}
