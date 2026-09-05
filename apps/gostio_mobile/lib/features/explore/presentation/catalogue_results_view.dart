import 'package:flutter/material.dart';

import '../../../core/paging/paged_notifier.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/paged_list.dart';
import '../data/listing_filters.dart';
import 'catalogue.dart';

// One catalogue's answers, and what is narrowing them. Both catalogues are
// drawn by this because a stay and a term differ in what they are filtered by
// rather than in how a filtered list reads: a bar of what is in force, and a
// list of cards under it.
//
// The filters in force are named beside the button that opens them, so taking
// one off is a tap on the phrase that put it on rather than a trip back into
// the sheet.
class CatalogueResultsView<TItem, TQuery extends ListingFilters<TQuery>>
    extends StatelessWidget {
  const CatalogueResultsView({
    required this.catalogue,
    required this.results,
    required this.itemBuilder,
    required this.onOpenFilters,
    super.key,
  });

  final Catalogue catalogue;
  final PagedNotifier<TItem, TQuery> results;
  final Widget Function(BuildContext context, TItem item) itemBuilder;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: results,
      builder: (BuildContext context, Widget? _) {
        final TQuery query = results.query;
        final List<AppliedFilter<TQuery>> applied = query.applied;

        return Column(
          children: <Widget>[
            _FilterBar<TQuery>(
              applied: applied,
              onOpenFilters: onOpenFilters,
              onRemove: results.apply,
            ),
            Expanded(
              child: PagedList<TItem>(
                items: results.items,
                totalCount: results.totalCount,
                itemBuilder: itemBuilder,
                onMore: results.more,
                isLoading: results.isLoading,
                isAppending: results.isAppending,
                failureMessage: results.failureMessage,
                failureTraceId: results.failureTraceId,
                onRetry: results.retry,
                onRefresh: results.reload,
                noun: catalogue.noun,
                emptyTitle: catalogue.emptyTitle,
                emptyMessage: applied.isEmpty && query.title == null
                    ? 'Nothing has been listed here yet.'
                    : catalogue.emptyMessage,
                emptyAction: applied.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => results.apply(query.cleared),
                        child: const Text('Clear filters'),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterBar<TQuery extends ListingFilters<TQuery>>
    extends StatelessWidget {
  const _FilterBar({
    required this.applied,
    required this.onOpenFilters,
    required this.onRemove,
  });

  final List<AppliedFilter<TQuery>> applied;
  final VoidCallback onOpenFilters;
  final ValueChanged<TQuery> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          OutlinedButton.icon(
            // A button in this bar is as wide as its words. The full-width
            // minimum every other button in the client is given would ask for
            // the whole row and leave the chips beside it nowhere to go.
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll<Size>(
                Size(0, AppSizes.touchTarget),
              ),
            ),
            onPressed: onOpenFilters,
            icon: const Icon(Icons.tune_rounded, size: AppSizes.iconSmall),
            label: Text(
              applied.isEmpty ? 'Filters' : 'Filters (${applied.length})',
            ),
          ),
          if (applied.isNotEmpty)
            Expanded(
              // The chips run off the edge rather than wrapping onto a second
              // line: the bar sits over the results and a filter added should
              // not push a card off the screen.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Row(
                  children: <Widget>[
                    for (final AppliedFilter<TQuery> filter in applied)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: AppChip.removable(
                          filter.label,
                          onRemove: () => onRemove(filter.without),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
