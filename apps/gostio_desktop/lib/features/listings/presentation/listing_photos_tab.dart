import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/formatting/app_numbers.dart';
import '../../../core/models/image_upload.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/tone.dart';
import '../../../core/validation/image_rules.dart';
import '../../../core/widgets/api_image.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/listing_address.dart';
import '../data/listing_photo.dart';
import '../data/listing_photos_repository.dart';
import 'listing_photos_notifier.dart';

class ListingPhotosTab extends StatelessWidget {
  const ListingPhotosTab({
    required this.listing,
    required this.onCoverMayChange,
    super.key,
  });

  final ListingAddress listing;
  final VoidCallback onCoverMayChange;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ListingPhotosNotifier>(
      create: (BuildContext context) {
        final ListingPhotosNotifier photos = ListingPhotosNotifier(
          context.read<ListingPhotosRepository>(),
          listing: listing,
          onCoverMayChange: onCoverMayChange,
        );
        unawaited(photos.load());

        return photos;
      },
      child: const _Gallery(),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final ListingPhotosNotifier photos = context.watch<ListingPhotosNotifier>();

    if (photos.isLoading) {
      return const LoadingState(message: 'Reading the photographs');
    }

    if (photos.failureMessage case final String message
        when photos.items.isEmpty) {
      return ErrorState(
        message: message,
        onRetry: photos.load,
        traceId: photos.failureTraceId,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Summary(photos: photos),
          if (photos.failureMessage case final String message) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(message),
          ],
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: photos.items.isEmpty
                ? const EmptyState(
                    title: 'No photographs yet',
                    message:
                        'The first one uploaded leads the listing, and any of '
                        'the others can take its place later.',
                  )
                : _Wall(photos: photos),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.photos});

  final ListingPhotosNotifier photos;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(_line, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: AppSpacing.lg),
        FilledButton.icon(
          onPressed: photos.isBusy ? null : () => _add(photos),
          icon: const Icon(Icons.add, size: AppSizes.iconSmall),
          label: const Text('Add photos'),
        ),
      ],
    );
  }

  String get _line {
    if (photos.isUploading) {
      return 'Uploading ${photos.uploading} of ${photos.chosen}';
    }

    final int count = photos.items.length;
    if (count == 0) {
      return 'A listing with no photograph shows an empty frame in a search.';
    }

    return '$count ${count == 1 ? 'photograph' : 'photographs'} · '
        '${AppNumbers.size(photos.totalBytes)} · the cover leads the listing';
  }
}

class _Wall extends StatelessWidget {
  const _Wall({required this.photos});

  final ListingPhotosNotifier photos;

  @override
  Widget build(BuildContext context) {
    ListingPhoto? cover;
    final List<ListingPhoto> rest = <ListingPhoto>[];

    for (final ListingPhoto photo in photos.items) {
      if (photo.isCover && cover == null) {
        cover = photo;
      } else {
        rest.add(photo);
      }
    }

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (cover case final ListingPhoto leading) ...<Widget>[
            _Tile(
              photo: leading,
              photos: photos,
              width: AppSizes.photoCover,
              height: AppSizes.photoCoverHeight,
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
          Expanded(
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: <Widget>[
                for (final ListingPhoto photo in rest)
                  _Tile(
                    photo: photo,
                    photos: photos,
                    width: AppSizes.photoTile,
                    height: AppSizes.photoTileHeight,
                  ),
                if (photos.isUploading) const _Arriving(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({
    required this.photo,
    required this.photos,
    required this.width,
    required this.height,
  });

  final ListingPhoto photo;
  final ListingPhotosNotifier photos;
  final double width;
  final double height;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ListingPhoto photo = widget.photo;
    final bool isBusy = widget.photos.busyPhotoId == photo.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MouseRegion(
          onEnter: (PointerEnterEvent event) =>
              setState(() => _isHovered = true),
          onExit: (PointerExitEvent event) =>
              setState(() => _isHovered = false),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: AppRadii.large,
              border: Border.all(color: _edge, width: _edgeWidth),
            ),
            child: ClipRRect(
              borderRadius: AppRadii.large,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  AnimatedScale(
                    scale: _isHovered ? _zoom : 1,
                    duration: _rise,
                    curve: Curves.easeOutCubic,
                    child: ApiImage(
                      path: widget.photos.listing.photoContent(photo.id),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  if (photo.isCover)
                    const Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: StatusChip('Cover', tone: Tone.informative),
                    ),
                  _Actions(
                    isShown: _isHovered && !widget.photos.isBusy,
                    isCover: photo.isCover,
                    onCover: () => widget.photos.setCover(photo.id),
                    onDelete: _confirmDelete,
                  ),
                  if (isBusy) const _Working(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: widget.width,
          child: Text(
            '${AppNumbers.size(photo.sizeInBytes)} · '
            '${AppDates.date(photo.uploadedAt)}',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.inkFaint),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color get _edge {
    if (widget.photo.isCover) {
      return AppColors.indigo;
    }

    return _isHovered ? AppColors.borderStrong : AppColors.border;
  }

  double get _edgeWidth =>
      widget.photo.isCover ? AppSizes.focusRing : AppSizes.hairline;

  Future<void> _confirmDelete() async {
    final ListingPhoto photo = widget.photo;

    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Delete this photograph?',
      message: _consequence,
      confirmLabel: 'Delete photograph',
      isDestructive: true,
    );

    if (agreed) {
      await widget.photos.remove(photo.id);
    }
  }

  String get _consequence {
    const String undone = 'This cannot be undone.';

    if (!widget.photo.isCover) {
      return undone;
    }

    return widget.photos.items.length == 1
        ? 'It is the only one, so the listing is left showing no photograph at '
              'all until another is added. $undone'
        : 'It leads the listing, so the next one takes its place. $undone';
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.isShown,
    required this.isCover,
    required this.onCover,
    required this.onDelete,
  });

  final bool isShown;
  final bool isCover;
  final VoidCallback onCover;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isShown,
      child: AnimatedOpacity(
        opacity: isShown ? 1 : 0,
        duration: _rise,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(gradient: _scrim),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                _Action(
                  icon: Icons.star_outline,
                  tooltip: isCover
                      ? 'This one already leads the listing'
                      : 'Make this the cover',
                  onPressed: isCover ? null : onCover,
                ),
                _Action(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete this photograph',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      color: AppColors.surface,
      disabledColor: AppColors.surface.withValues(alpha: 0.45),
      iconSize: AppSizes.icon,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: AppSizes.control,
        height: AppSizes.control,
      ),
      hoverColor: AppColors.surface.withValues(alpha: 0.16),
    );
  }
}

class _Working extends StatelessWidget {
  const _Working();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink.withValues(alpha: 0.45),
      child: const Center(
        child: SizedBox(
          width: AppSizes.spinner,
          height: AppSizes.spinner,
          child: CircularProgressIndicator(
            strokeWidth: AppSizes.stroke,
            color: AppColors.surface,
          ),
        ),
      ),
    );
  }
}

class _Arriving extends StatelessWidget {
  const _Arriving();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.photoTile,
      height: AppSizes.photoTileHeight,
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: AppSizes.spinner,
        height: AppSizes.spinner,
        child: CircularProgressIndicator(strokeWidth: AppSizes.stroke),
      ),
    );
  }
}

Future<void> _add(ListingPhotosNotifier photos) async {
  final List<PlatformFile> chosen = await FilePicker.pickFiles(
    dialogTitle: 'Choose photographs',
    type: FileType.custom,
    allowedExtensions: ImageRules.extensions,
  );

  final List<ImageUpload> images = <ImageUpload>[];

  try {
    for (final PlatformFile file in chosen) {
      images.add(ImageUpload(name: file.name, bytes: await file.readAsBytes()));
    }
  } on Exception catch (failure) {
    photos.refuse('That file could not be read. $failure');

    return;
  }

  await photos.add(images);
}

const Duration _rise = Duration(milliseconds: 160);

const double _zoom = 1.04;

final LinearGradient _scrim = LinearGradient(
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
  colors: <Color>[
    AppColors.ink.withValues(alpha: 0.8),
    AppColors.ink.withValues(alpha: 0),
  ],
);
