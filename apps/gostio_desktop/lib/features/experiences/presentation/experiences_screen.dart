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
import '../data/experiences_repository.dart';
import 'experience_detail_screen.dart';
import 'experience_filter_options.dart';
import 'experience_filters.dart';
import 'experiences_notifier.dart';

class ExperiencesScreen extends StatefulWidget {
  const ExperiencesScreen({
    required this.asAdministrator,
    this.hostId,
    super.key,
  });

  final bool asAdministrator;
  final int? hostId;

  @override
  State<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends State<ExperiencesScreen> {
  late final Future<ExperienceFilterOptions> _options;

  @override
  void initState() {
    super.initState();
    _options = ExperienceFilterOptions.load(
      context.read<ReferenceRepository>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ExperiencesNotifier>(
      create: (BuildContext context) {
        final ExperiencesNotifier experiences = ExperiencesNotifier(
          context.read<ExperiencesRepository>(),
          hostId: widget.hostId,
        );
        unawaited(experiences.reload());

        return experiences;
      },
      child: _Body(options: _options, asAdministrator: widget.asAdministrator),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.options, required this.asAdministrator});

  final Future<ExperienceFilterOptions> options;
  final bool asAdministrator;

  @override
  Widget build(BuildContext context) {
    final ExperiencesNotifier experiences = context
        .watch<ExperiencesNotifier>();
    final String? failure = experiences.failureMessage;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FutureBuilder<ExperienceFilterOptions>(
            future: options,
            builder: (
              BuildContext context,
              AsyncSnapshot<ExperienceFilterOptions> snapshot,
            ) => _filters(context, snapshot, experiences),
          ),
          if (failure != null && experiences.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(failure),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSizes.stroke,
            child: experiences.isLoading
                ? const LinearProgressIndicator()
                : null,
          ),
          Expanded(
            child: RecordTable<Experience>(
              columns: _columns,
              rows: experiences.items,
              onRowOpen: (Experience row) =>
                  _open(context, experiences, id: row.id),
              empty: _Nothing(experiences: experiences),
              footer: PaginationFooter(
                page: experiences.page,
                pageSize: experiences.pageSize,
                totalCount: experiences.totalCount,
                onPageChanged: experiences.openPage,
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
    AsyncSnapshot<ExperienceFilterOptions> snapshot,
    ExperiencesNotifier experiences,
  ) {
    final Widget filters = ExperienceFilters(
      options: snapshot.data ?? ExperienceFilterOptions.none,
      applied: experiences.query,
      isLoading: experiences.isLoading,
      onChanged: experiences.apply,
      trailing: FilledButton.icon(
        onPressed: () => _open(context, experiences),
        icon: const Icon(Icons.add, size: AppSizes.iconSmall),
        label: const Text('New experience'),
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
    ExperiencesNotifier experiences, {
    int? id,
  }) async {
    final Experience? changed = await Navigator.of(context).push<Experience>(
      MaterialPageRoute<Experience>(
        builder: (BuildContext context) => ExperienceDetailScreen(
          asAdministrator: asAdministrator,
          experienceId: id,
        ),
      ),
    );

    if (changed != null) {
      await experiences.reload();
    }
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.experiences});

  final ExperiencesNotifier experiences;

  @override
  Widget build(BuildContext context) {
    if (experiences.isLoading) {
      return const LoadingState();
    }

    if (experiences.failureMessage case final String failure) {
      return ErrorState(message: failure, onRetry: experiences.reload);
    }

    return experiences.query.isEmpty
        ? const EmptyState(
            title: 'No experiences',
            message: 'Things to do appear here as hosts publish them.',
          )
        : const EmptyState(
            title: 'Nothing matches',
            message: 'No experience answers every filter set above.',
          );
  }
}

// The share of the width left over that a text column takes: the title reads
// longest, and the two names beside it are read as one group.
const int _titleShare = 3;
const int _nameShare = 2;

final List<TableColumn<Experience>> _columns = <TableColumn<Experience>>[
  TableColumn<Experience>(
    label: '',
    width: AppSizes.thumbnailColumn,
    cell: (BuildContext context, Experience row) => ApiImage(
      path: row.coverPath,
      width: AppSizes.thumbnail,
      height: AppSizes.thumbnail,
    ),
  ),
  TableColumn<Experience>.text(
    label: 'Title',
    read: (Experience row) => row.title,
    flex: _titleShare,
  ),
  TableColumn<Experience>.text(
    label: 'City',
    read: (Experience row) => row.cityName,
    flex: _nameShare,
  ),
  TableColumn<Experience>.text(
    label: 'Category',
    read: (Experience row) => row.experienceCategoryName,
    flex: _nameShare,
  ),
  TableColumn<Experience>.number(
    label: 'Price / person',
    read: (Experience row) => AppNumbers.money(row.pricePerPerson),
  ),
  TableColumn<Experience>.text(
    label: 'Runs for',
    read: (Experience row) => AppDurations.inWords(row.durationMinutes),
    width: AppSizes.numericColumn,
  ),
  TableColumn<Experience>.number(
    label: 'Rating',
    read: _rating,
    width: AppSizes.compactColumn,
  ),
  TableColumn<Experience>(
    label: 'Status',
    width: AppSizes.statusColumn,
    cell: (BuildContext context, Experience row) => StatusChip(
      ListingStatus.of(row.isActive).label,
      tone: row.isActive ? Tone.positive : Tone.neutral,
    ),
  ),
  TableColumn<Experience>.text(
    label: 'Created',
    read: (Experience row) => AppDates.date(row.createdAt),
    width: AppSizes.dateColumn,
  ),
];

String _rating(Experience row) => row.averageRating == null
    ? '—'
    : '${AppNumbers.rating(row.averageRating!)} (${row.reviewCount})';
