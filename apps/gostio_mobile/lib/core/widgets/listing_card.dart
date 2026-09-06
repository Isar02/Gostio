import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';
import 'api_image.dart';
import 'app_card.dart';
import 'rating_stars.dart';
import 'status_chip.dart';

// One row of either catalogue. It takes what it draws rather than a model,
// because a stay and an experience are different rows of the same shape and
// neither belongs to this layer.
//
// The API answers a cover as an address, never as bytes, so the picture
// arrives after the card. The card is laid out to be right before it does.
class ListingCard extends StatelessWidget {
  const ListingCard({
    required this.title,
    required this.place,
    required this.price,
    this.priceUnit,
    this.coverPath,
    this.rating,
    this.reviewCount,
    this.status,
    this.statusTone = Tone.neutral,
    this.isFavorite = false,
    this.notes = const <String>[],
    this.onTap,
    super.key,
  });

  final String title;
  final String place;
  final double price;
  final String? priceUnit;
  final String? coverPath;
  final double? rating;
  final int? reviewCount;
  final String? status;
  final Tone statusTone;

  // Saved by whoever is reading. It is drawn here and turned on the listing's
  // own screen: a heart small enough to sit on a card is smaller than the
  // thumb that would have to hit it.
  final bool isFavorite;

  // What the list this card came from has to add under the facts, ruled off
  // from them. Lines rather than a widget, because the card is announced as
  // one sentence and anything drawn inside it that it cannot say would be
  // read by an eye and by nothing else.
  final List<String> notes;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      semanticLabel: _spoken,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              AspectRatio(
                aspectRatio: AppSizes.coverAspect,
                child: ApiImage(
                  path: coverPath,
                  borderRadius: BorderRadius.zero,
                  width: double.infinity,
                ),
              ),
              if (status case final String status)
                Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.md,
                  child: StatusChip(status, tone: statusTone),
                ),
              if (isFavorite)
                const Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: _Saved(),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
                if (_hasReviewFigures) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  RatingStars(rating: rating, reviewCount: reviewCount),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Text(AppNumbers.money(price), style: text.titleSmall),
                    if (priceUnit case final String unit) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        unit,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                if (notes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  for (final String note in notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _Note(note),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Whether the list this card came from carried anything about the reviews.
  // A row that carries neither figure — a saved listing is one — knows nothing
  // about them rather than knowing there are none, and saying the second would
  // be a figure the card invented.
  bool get _hasReviewFigures => rating != null || reviewCount != null;

  // The card is one thing, and this is it said once rather than as the four
  // fragments it is drawn from.
  String get _spoken {
    final StringBuffer spoken = StringBuffer('$title, $place');

    if (rating case final double rating when reviewCount != 0) {
      spoken.write(', rated ${AppNumbers.rating(rating)}');
      if (reviewCount case final int count) {
        spoken.write(' from ${AppNumbers.counted(count, "review")}');
      }
    } else if (_hasReviewFigures) {
      spoken.write(', no reviews yet');
    }

    spoken.write(', ${AppNumbers.money(price)}');
    if (priceUnit case final String unit) {
      spoken.write(' $unit');
    }

    if (status case final String status) {
      spoken.write(', $status');
    }

    if (isFavorite) {
      spoken.write(', saved');
    }

    for (final String note in notes) {
      spoken.write(', $note');
    }

    return spoken.toString();
  }
}

// One line the list added under the facts. The dot marks it as one of several
// rather than standing for anything, which is why it is a shape and not an
// icon a reader would have to learn.
class _Note extends StatelessWidget {
  const _Note(this.words);

  final String words;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(top: AppSpacing.sm),
          width: AppSizes.noteDot,
          height: AppSizes.noteDot,
          decoration: const BoxDecoration(
            color: AppColors.iris,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            words,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }
}

// The mark on a saved listing. It answers nothing: it is the state the card
// was read in, and it is turned where there is room for a control.
class _Saved extends StatelessWidget {
  const _Saved();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.favorite_rounded,
        size: AppSizes.iconSmall,
        color: AppColors.indigo,
      ),
    );
  }
}
