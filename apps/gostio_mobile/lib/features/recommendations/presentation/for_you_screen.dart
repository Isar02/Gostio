import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/paged_list.dart';
import '../data/recommendations_repository.dart';
import 'recommendation_card.dart';
import 'recommendations_notifier.dart';

// What the server suggests to this account, one catalogue at a time. The
// toggle is the same one Explore carries, because it moves between the same
// two catalogues; what is under it is a ranking rather than a search, so there
// is no field and no filter.
//
// This is the tab's body rather than its screen: the bar over it is the
// shell's, because the bell in it belongs to every tab and not to this one.
class ForYouScreen extends StatelessWidget {
  const ForYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RecommendationsNotifier>(
      create: (BuildContext context) =>
          RecommendationsNotifier(context.read<RecommendationsRepository>()),
      child: const _ForYou(),
    );
  }
}

class _ForYou extends StatelessWidget {
  const _ForYou();

  @override
  Widget build(BuildContext context) {
    final RecommendationsNotifier picks = context
        .watch<RecommendationsNotifier>();
    final List<Recommendation> ranking = picks.itemsBelongToQuery
        ? picks.items
        : const <Recommendation>[];

    return Column(
      children: <Widget>[
        _CatalogueToggle(
          catalogue: picks.query,
          onChosen: (ListingKind chosen) {
            if (chosen != picks.query) {
              unawaited(picks.apply(chosen));
            }
          },
        ),
        Expanded(
          // The list is keyed on the catalogue so that moving between the
          // two starts at the top of the new ranking. Without it the reader
          // keeps the offset they had scrolled to in the other one, which is
          // a place in a list that is no longer there.
          child: PagedList<Recommendation>(
            key: ValueKey<ListingKind>(picks.query),
            // `apply` keeps the last successful page while the next query is
            // in flight or refused. That is useful for a narrower search, but
            // one catalogue must never be drawn under the other's name.
            items: ranking,
            totalCount: picks.totalCount,
            noun: 'suggestions',
            isLoading: picks.isLoading,
            isAppending: picks.isAppending,
            failureMessage: picks.failureMessage,
            failureTraceId: picks.failureTraceId,
            onMore: picks.more,
            onRetry: picks.retry,
            onRefresh: picks.reload,
            emptyTitle: 'Nothing to suggest here yet',
            emptyMessage:
                'Search, save a listing or book a stay, and this fills with '
                'what those say about you.',
            itemBuilder: (BuildContext context, Recommendation picked) =>
                RecommendationCard(picked),
          ),
        ),
      ],
    );
  }
}

class _CatalogueToggle extends StatelessWidget {
  const _CatalogueToggle({required this.catalogue, required this.onChosen});

  final ListingKind catalogue;
  final ValueChanged<ListingKind> onChosen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<ListingKind>(
          segments: const <ButtonSegment<ListingKind>>[
            ButtonSegment<ListingKind>(
              value: ListingKind.accommodation,
              label: Text('Stays'),
            ),
            ButtonSegment<ListingKind>(
              value: ListingKind.experience,
              label: Text('Experiences'),
            ),
          ],
          selected: <ListingKind>{catalogue},
          showSelectedIcon: false,
          onSelectionChanged: (Set<ListingKind> chosen) =>
              onChosen(chosen.single),
        ),
      ),
    );
  }
}
