import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/api_image.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/pagination_footer.dart';
import '../../../core/widgets/record_table.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../listings/presentation/listing_status.dart';
import '../../reference/data/reference_repository.dart';
import '../data/accommodations_repository.dart';
import 'accommodation_detail_screen.dart';
import 'accommodation_filter_options.dart';
import 'accommodation_filters.dart';
import 'accommodations_notifier.dart';

class AccommodationsScreen extends StatefulWidget {
  const AccommodationsScreen({
    required this.asAdministrator,
    this.hostId,
    super.key,
  });

  final bool asAdministrator;
  final int? hostId;

  @override
  State<AccommodationsScreen> createState() => _AccommodationsScreenState();
}

class _AccommodationsScreenState extends State<AccommodationsScreen> {
  late final Future<AccommodationFilterOptions> _options;

  @override
  void initState() {
    super.initState();
    _options = AccommodationFilterOptions.load(
      context.read<ReferenceRepository>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AccommodationsNotifier>(
      create: (BuildContext context) {
        final AccommodationsNotifier accommodations = AccommodationsNotifier(
          context.read<AccommodationsRepository>(),
          hostId: widget.hostId,
        );
        unawaited(accommodations.reload());

        return accommodations;
      },
      child: _Body(options: _options, asAdministrator: widget.asAdministrator),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.options, required this.asAdministrator});

  final Future<AccommodationFilterOptions> options;
  final bool asAdministrator;

  @override
  Widget build(BuildContext context) {
    final AccommodationsNotifier accommodations = context
        .watch<AccommodationsNotifier>();
    final String? failure = accommodations.failureMessage;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FutureBuilder<AccommodationFilterOptions>(
            future: options,
            builder: (
              BuildContext context,
              AsyncSnapshot<AccommodationFilterOptions> snapshot,
            ) => _filters(context, snapshot, accommodations),
          ),
          if (failure != null && accommodations.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(failure),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSizes.stroke,
            child: accommodations.isLoading
                ? const LinearProgressIndicator()
                : null,
          ),
          Expanded(
            child: RecordTable<Accommodation>(
              columns: _columns,
              rows: accommodations.items,
              onRowOpen: (Accommodation row) =>
                  _open(context, accommodations, id: row.id),
              empty: _Nothing(accommodations: accommodations),
              footer: PaginationFooter(
                page: accommodations.page,
                pageSize: accommodations.pageSize,
                totalCount: accommodations.totalCount,
                onPageChanged: accommodations.openPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A filter list that did not arrive leaves its dropdown holding nothing,
  // which is worth saying rather than showing as an empty menu.
  Widget _filters(
    BuildContext context,
    AsyncSnapshot<AccommodationFilterOptions> snapshot,
    AccommodationsNotifier accommodations,
  ) {
    final Widget filters = AccommodationFilters(
      options: snapshot.data ?? AccommodationFilterOptions.none,
      applied: accommodations.query,
      isLoading: accommodations.isLoading,
      onChanged: accommodations.apply,
      trailing: FilledButton.icon(
        onPressed: () => _open(context, accommodations),
        icon: const Icon(Icons.add, size: AppSizes.iconSmall),
        label: const Text('New listing'),
      ),
    );

    if (snapshot.error case final Object failure) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppNotice('The filter lists could not be read. $failure'),
          const SizedBox(height: AppSpacing.md),
          filters,
        ],
      );
    }

    return filters;
  }

  // The detail is pushed over the list rather than beside it, and the list
  // reloads only when it hands back the row it wrote.
  Future<void> _open(
    BuildContext context,
    AccommodationsNotifier accommodations, {
    int? id,
  }) async {
    final Accommodation? changed = await Navigator.of(context)
        .push<Accommodation>(
          MaterialPageRoute<Accommodation>(
            builder: (BuildContext context) => AccommodationDetailScreen(
              asAdministrator: asAdministrator,
              accommodationId: id,
            ),
          ),
        );

    if (changed != null) {
      await accommodations.reload();
    }
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.accommodations});

  final AccommodationsNotifier accommodations;

  @override
  Widget build(BuildContext context) {
    if (accommodations.isLoading) {
      return const LoadingState();
    }

    if (accommodations.failureMessage case final String failure) {
      return ErrorState(message: failure, onRetry: accommodations.reload);
    }

    return accommodations.query.isEmpty
        ? const EmptyState(
            title: 'No accommodations',
            message: 'Listings appear here as hosts publish them.',
          )
        : const EmptyState(
            title: 'Nothing matches',
            message: 'No listing answers every filter set above.',
          );
  }
}

// The share of the width left over that a text column takes: the title reads
// longest, and the three names beside it are read as one group.
const int _titleShare = 3;
const int _nameShare = 2;

final List<TableColumn<Accommodation>> _columns = <TableColumn<Accommodation>>[
  TableColumn<Accommodation>(
    label: '',
    width: AppSizes.thumbnailColumn,
    cell: (BuildContext context, Accommodation row) => ApiImage(
      path: row.coverPath,
      width: AppSizes.thumbnail,
      height: AppSizes.thumbnail,
    ),
  ),
  TableColumn<Accommodation>.text(
    label: 'Title',
    read: (Accommodation row) => row.title,
    flex: _titleShare,
  ),
  TableColumn<Accommodation>.text(
    label: 'City',
    read: (Accommodation row) => row.cityName,
    flex: _nameShare,
  ),
  TableColumn<Accommodation>.text(
    label: 'Type',
    read: (Accommodation row) => row.accommodationTypeName,
    flex: _nameShare,
  ),
  TableColumn<Accommodation>.text(
    label: 'Category',
    read: (Accommodation row) => row.accommodationCategoryName,
    flex: _nameShare,
  ),
  TableColumn<Accommodation>.number(
    label: 'Price / night',
    read: (Accommodation row) => AppNumbers.money(row.pricePerNight),
  ),
  TableColumn<Accommodation>.number(
    label: 'Guests',
    read: (Accommodation row) => '${row.maxGuests}',
    width: AppSizes.compactColumn,
  ),
  TableColumn<Accommodation>.number(
    label: 'Rating',
    read: _rating,
    width: AppSizes.compactColumn,
  ),
  TableColumn<Accommodation>(
    label: 'Status',
    width: AppSizes.statusColumn,
    cell: (BuildContext context, Accommodation row) => StatusChip(
      ListingStatus.of(row.isActive).label,
      tone: row.isActive ? Tone.positive : Tone.neutral,
    ),
  ),
  TableColumn<Accommodation>.text(
    label: 'Created',
    read: (Accommodation row) => AppDates.date(row.createdAt),
    width: AppSizes.dateColumn,
  ),
];

String _rating(Accommodation row) => row.averageRating == null
    ? '—'
    : '${AppNumbers.rating(row.averageRating!)} (${row.reviewCount})';
