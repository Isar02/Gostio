import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/api_image.dart';
import '../../../core/widgets/status_chip.dart';

// The pictures a listing leads with, one at a time at the width of the phone.
// A grid of thumbnails on a screen this narrow is a row of stamps; a strip is
// the picture the reader came for.
//
// The API answers a gallery as addresses rather than as bytes, so the space
// each picture will take is held before it arrives and the words below the
// gallery do not move once it does.
class ListingGallery extends StatefulWidget {
  const ListingGallery({
    required this.address,
    required this.photos,
    super.key,
  });

  final ListingAddress address;
  final List<ListingPhoto> photos;

  @override
  State<ListingGallery> createState() => _ListingGalleryState();
}

class _ListingGalleryState extends State<ListingGallery> {
  final PageController _pages = PageController();

  int _shown = 0;

  @override
  void dispose() {
    _pages.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ListingPhoto> photos = widget.photos;

    return AspectRatio(
      aspectRatio: AppSizes.coverAspect,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: photos.isEmpty
                ? const ApiImage(
                    path: null,
                    borderRadius: BorderRadius.zero,
                    width: double.infinity,
                  )
                : PageView.builder(
                    controller: _pages,
                    itemCount: photos.length,
                    onPageChanged: (int page) => setState(() => _shown = page),
                    itemBuilder: (BuildContext context, int index) => ApiImage(
                      path: widget.address.photoContent(photos[index].id),
                      borderRadius: BorderRadius.zero,
                      width: double.infinity,
                    ),
                  ),
          ),
          if (photos.length > 1)
            Positioned(
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: StatusChip('${_shown + 1} of ${photos.length}'),
            ),
        ],
      ),
    );
  }
}
