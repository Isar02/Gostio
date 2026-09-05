import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/listing_detail.dart';
import '../data/listing_repository.dart';
import 'favorite_edits.dart';
import 'listing_amenities.dart';
import 'listing_availability.dart';
import 'listing_detail_notifier.dart';
import 'listing_gallery.dart';
import 'listing_place.dart';
import 'listing_reviews.dart';
import 'listing_reviews_notifier.dart';
import 'listing_summary.dart';

// One listing, and everything that belongs to it: the row at the top and its
// pictures, amenities, availability and reviews under it, each read from a
// route of its own.
//
// It is pushed into whichever tab it was opened from, so the bar under it
// stays and closing it comes back to the list the reader was in.
class ListingScreen extends StatelessWidget {
  const ListingScreen(this.address, {super.key});

  static Future<void> open(BuildContext context, ListingAddress address) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => ListingScreen(address),
        ),
      );

  final ListingAddress address;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<ListingDetailNotifier>(
          create: (BuildContext context) => ListingDetailNotifier(
            context.read<ListingRepository>(),
            context.read<FavoriteEdits>(),
            address,
          ),
        ),
        // The reviews are their own list because they are paged and the rest
        // of the screen is not, and they are read with it because the section
        // that draws them is on the first screenful.
        ChangeNotifierProvider<ListingReviewsNotifier>(
          lazy: false,
          create: (BuildContext context) => ListingReviewsNotifier(
            context.read<ListingRepository>(),
            address,
          ),
        ),
      ],
      child: const _Listing(),
    );
  }
}

class _Listing extends StatelessWidget {
  const _Listing();

  @override
  Widget build(BuildContext context) {
    return Consumer<ListingDetailNotifier>(
      builder:
          (BuildContext context, ListingDetailNotifier listing, Widget? _) =>
              Scaffold(
                appBar: AppBar(
                  title: Text(
                    listing.overview?.detail.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: <Widget>[
                    if (listing.overview != null) _Heart(listing),
                  ],
                ),
                body: SafeArea(child: _body(listing)),
              ),
    );
  }

  Widget _body(ListingDetailNotifier listing) {
    // A listing already on the screen stays there while it is read again, so
    // a refusal on the second read is not a page that empties itself.
    if (listing.overview case final ListingOverview overview) {
      return _Sections(overview);
    }

    if (listing.isLoading) {
      return const LoadingState();
    }

    return ErrorState(
      message: listing.failureMessage ?? 'This listing could not be opened.',
      traceId: listing.failureTraceId,
      onRetry: listing.load,
    );
  }
}

class _Sections extends StatelessWidget {
  const _Sections(this.overview);

  final ListingOverview overview;

  @override
  Widget build(BuildContext context) {
    final ListingDetail detail = overview.detail;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: <Widget>[
        // The gallery is the width of the phone; everything under it is read
        // in a column with a margin.
        ListingGallery(address: detail.address, photos: overview.photos),
        _Block(child: ListingSummary(detail)),
        if (overview.amenities.isNotEmpty)
          _Block(child: ListingAmenities(overview.amenities)),
        _Block(child: ListingPlace(detail)),
        if (detail case StayDetail(:final Accommodation stay))
          _Block(child: ListingAvailability(stay.id)),
        _Block(child: ListingReviews(detail)),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        0,
      ),
      child: child,
    );
  }
}

// The favourite. It is written before it is drawn: a heart that fills on the
// tap and empties again when the server refuses says the client was guessing.
class _Heart extends StatelessWidget {
  const _Heart(this.listing);

  final ListingDetailNotifier listing;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: listing.isSavingFavorite ? null : () => _toggle(context),
      tooltip: listing.isFavorite ? 'Remove from saved' : 'Save this listing',
      icon: listing.isSavingFavorite
          ? const SizedBox(
              width: AppSizes.iconSmall,
              height: AppSizes.iconSmall,
              child: CircularProgressIndicator(strokeWidth: AppSizes.stroke),
            )
          : Icon(
              listing.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: listing.isFavorite ? AppColors.indigo : null,
            ),
    );
  }

  Future<void> _toggle(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    if (await listing.toggleFavorite()) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(listing.favoriteRefusal ?? 'That could not be saved.'),
      ),
    );
  }
}
