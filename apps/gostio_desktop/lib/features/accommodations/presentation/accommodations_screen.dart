import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/formatting/app_numbers.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/tone.dart';
import '../../../core/widgets/api_image.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/pagination_footer.dart';
import '../../../core/widgets/record_table.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../reference/data/reference_repository.dart';
import '../data/accommodation.dart';
import '../data/accommodations_repository.dart';
import 'accommodation_filter_options.dart';
import 'accommodation_filters.dart';
import 'accommodations_notifier.dart';
import 'listing_status.dart';

class AccommodationsScreen extends StatefulWidget {
  const AccommodationsScreen({this.hostId, super.key});

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
      child: _Body(options: _options),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.options});

  final Future<AccommodationFilterOptions> options;

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
            ) => _filters(snapshot, accommodations),
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
    AsyncSnapshot<AccommodationFilterOptions> snapshot,
    AccommodationsNotifier accommodations,
  ) {
    final Widget filters = AccommodationFilters(
      options: snapshot.data ?? AccommodationFilterOptions.none,
      applied: accommodations.query,
      isLoading: accommodations.isLoading,
      onChanged: accommodations.apply,
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
