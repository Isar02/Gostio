import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/api_image.dart';

// One article, drawn from the row the list handed it. Nothing is read here:
// the row a list of news answers carries the whole article, so a second read
// would ask the server for words it has already sent.
class ArticleScreen extends StatelessWidget {
  const ArticleScreen(this.item, {super.key});

  static Future<void> open(BuildContext context, NewsItem item) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => ArticleScreen(item),
        ),
      );

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('News')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
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
                  // The article itself says the moment it went out, hour
                  // included. The card that leads here is a teaser and carries
                  // the day alone.
                  Text(
                    AppDates.dateTime(item.publishedAt).toUpperCase(),
                    style: text.labelSmall?.copyWith(color: AppColors.iris),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(item.title, style: text.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    item.authorName,
                    style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                  // Said only where it happened, and in the words the reviews
                  // on a listing already use for the same thing.
                  if (item.modifiedAt case final DateTime edited) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Edited ${AppDates.dateTime(edited)}',
                      style: text.labelSmall?.copyWith(
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(),
                  const SizedBox(height: AppSpacing.lg),
                  for (final String paragraph in _paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(paragraph, style: text.bodyLarge),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // An article is one field on the row. A blank line between two runs of it is
  // the only structure the API carries, so it is the only one drawn.
  List<String> get _paragraphs => item.body
      .split(RegExp(r'\n\s*\n'))
      .map((String paragraph) => paragraph.trim())
      .where((String paragraph) => paragraph.isNotEmpty)
      .toList(growable: false);
}
