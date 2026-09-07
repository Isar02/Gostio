import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/api_image.dart';
import '../../../core/widgets/app_card.dart';

// One published article as a row. It is the same card in the strip on the
// landing and in the list behind it, held to a width in the first and left to
// fill in the second: two cards for one row would be two places to decide what
// an article looks like.
class NewsCard extends StatelessWidget {
  const NewsCard(this.item, {required this.onTap, this.width, super.key});

  final NewsItem item;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String published = AppDates.date(item.publishedAt);

    final Widget card = AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      semanticLabel: '${item.title}. Published $published',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
            aspectRatio: AppSizes.coverAspect,
            child: ApiImage(
              path: item.imagePath,
              borderRadius: BorderRadius.zero,
              width: double.infinity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  published.toUpperCase(),
                  style: text.labelSmall?.copyWith(color: AppColors.iris),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return width == null ? card : SizedBox(width: width, child: card);
  }
}
