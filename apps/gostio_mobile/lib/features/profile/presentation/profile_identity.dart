import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/api_image.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../data/picture_source.dart';
import 'profile_notifier.dart';
import 'profile_picture_sheet.dart';
import 'profile_write_lock.dart';

// Who this account is, and the one thing about it that is written here. The
// name comes before the control rather than after it: this is a profile, and
// what a reader looks for at the top of one is themselves.
//
// The picture is written the moment it is chosen rather than waiting on a Save
// beside it: it has an endpoint of its own, and a screen that kept a chosen
// photograph until some other button was pressed would be the worse surprise.
class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity({required this.account, super.key});

  final User account;

  @override
  Widget build(BuildContext context) {
    final ProfileNotifier profile = context.watch<ProfileNotifier>();
    final bool isWriting = context.watch<ProfileWriteLock>().isWriting;
    final TextTheme text = Theme.of(context).textTheme;
    final String? said = profile.pictureMessage;

    return Column(
      children: <Widget>[
        AccountAvatar(
          userId: account.id,
          name: account.fullName,
          hasImage: account.hasProfileImage,
          size: AppSizes.avatarLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          account.fullName,
          textAlign: TextAlign.center,
          style: text.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          account.username,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: isWriting ? null : () => _change(context),
          child: Text(_label(profile, hasPicture: account.hasProfileImage)),
        ),
        // The formats are a rule the reader cannot act on until they have
        // chosen, so the standing line is kept short and the whole of it is
        // said where a file was actually refused.
        Text(
          said ?? _footnote,
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(
            color: said == null ? AppColors.inkFaint : AppColors.danger,
          ),
        ),
      ],
    );
  }

  static String get _footnote =>
      'JPEG, PNG or WebP, at most '
      '${ImageRules.maximumBytes ~/ (1024 * 1024)} MB.';

  static String _label(ProfileNotifier profile, {required bool hasPicture}) {
    if (profile.isSavingPicture) {
      return 'Saving your picture';
    }

    return hasPicture ? 'Change your picture' : 'Add a picture';
  }

  Future<void> _change(BuildContext context) async {
    final PictureAct? act = await ProfilePictureSheet.show(
      context,
      hasPicture: account.hasProfileImage,
    );

    if (act == null || !context.mounted) {
      return;
    }

    switch (act) {
      case PictureAct.camera:
        await _write(context, PictureOrigin.camera, said: _wasUpdated);
      case PictureAct.gallery:
        await _write(context, PictureOrigin.gallery, said: _wasUpdated);
      case PictureAct.remove:
        await _remove(context);
    }
  }

  Future<void> _write(
    BuildContext context,
    PictureOrigin origin, {
    required String said,
  }) => _after(
    context,
    context.read<ProfileNotifier>().choosePicture(origin),
    said: said,
  );

  Future<void> _remove(BuildContext context) async {
    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Remove your picture?',
      message:
          'Your initials stand in its place until another one is chosen. The '
          'picture itself is gone.',
      confirmLabel: 'Remove picture',
      isDestructive: true,
    );

    if (!agreed || !context.mounted) {
      return;
    }

    await _after(
      context,
      context.read<ProfileNotifier>().removePicture(),
      said: 'Your picture was removed.',
    );
  }

  // The bytes at that address have changed, and neither the cache nor an
  // avatar already showing the old ones can see that on their own.
  Future<void> _after(
    BuildContext context,
    Future<bool> written, {
    required String said,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    if (!await written || !context.mounted) {
      return;
    }

    await ApiImage.forget(context, AccountAvatar.pathFor(account.id));

    messenger.showSnackBar(SnackBar(content: Text(said)));
  }

  static const String _wasUpdated = 'Your picture was updated.';
}
