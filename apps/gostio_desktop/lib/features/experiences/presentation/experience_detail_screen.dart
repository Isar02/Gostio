import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../listings/presentation/listing_photos_tab.dart';
import '../../listings/presentation/listing_status.dart';
import '../../reference/data/reference_repository.dart';
import '../../reservations/data/reservations_repository.dart';
import '../../users/data/users_repository.dart';
import '../data/experiences_repository.dart';
import 'experience_detail_notifier.dart';
import 'experience_form.dart';
import 'experience_slots_tab.dart';

class ExperienceDetailScreen extends StatelessWidget {
  const ExperienceDetailScreen({
    required this.asAdministrator,
    this.experienceId,
    super.key,
  });

  final bool asAdministrator;

  final int? experienceId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ExperienceDetailNotifier>(
      create: (BuildContext context) {
        final ExperienceDetailNotifier notifier = ExperienceDetailNotifier(
          context.read<ExperiencesRepository>(),
          context.read<ReferenceRepository>(),
          context.read<UsersRepository>(),
          context.read<ReservationsRepository>(),
          experienceId: experienceId,
          asAdministrator: asAdministrator,
        );
        unawaited(notifier.load());

        return notifier;
      },
      child: const _Detail(),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail();

  @override
  Widget build(BuildContext context) {
    final ExperienceDetailNotifier notifier = context
        .watch<ExperienceDetailNotifier>();

    if (notifier.isLoading) {
      return const LoadingState(message: 'Reading the experience');
    }

    // What the API said comes before anything this screen concludes: a load
    // that failed leaves every list empty, which is not the same as a table
    // that has nothing in it.
    if (notifier.failureMessage case final String message) {
      return ErrorState(
        message: message,
        onRetry: notifier.load,
        traceId: notifier.failureTraceId,
      );
    }

    if (notifier.experience == null && !notifier.isCreating) {
      return ErrorState(
        message: 'This experience could not be read.',
        onRetry: notifier.load,
      );
    }

    // A create form does not open while a table it draws from is empty.
    if (notifier.isCreating) {
      if (notifier.options.missingFor(asAdministrator: notifier.asAdministrator)
          case final String gap) {
        return _Unready(gap: gap);
      }
    }

    return DefaultTabController(
      length: _tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(notifier: notifier),
          const _Tabs(),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                ExperienceForm(
                  notifier: notifier,
                  onSaved: (Experience saved) =>
                      _saved(context, notifier, saved),
                  onDeleted: (Experience deleted) =>
                      _leave(context, deleted, '${deleted.title} was deleted.'),
                ),
                if (notifier.experienceId case final int id)
                  ListingPhotosTab(
                    listing: ListingAddress(ListingKind.experience, id),
                    onCoverMayChange: notifier.coverMayChange,
                  )
                else
                  _NotHereYet(tab: _tabs[1], isCreating: notifier.isCreating),
                if (notifier.experience case final Experience experience
                    when !notifier.isCreating)
                  ExperienceSlotsTab(
                    experienceId: experience.id,
                    durationMinutes: experience.durationMinutes,
                  )
                else
                  _NotHereYet(tab: _tabs[2], isCreating: notifier.isCreating),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // An edited row is already on the page the list is showing, so the screen
  // goes back to it. A created one is ordered by its title like every other and
  // no page can be promised to hold it, so the form stays and empties instead.
  static void _saved(
    BuildContext context,
    ExperienceDetailNotifier notifier,
    Experience saved,
  ) {
    if (!notifier.isCreating) {
      _leave(context, saved, '${saved.title} was updated.');

      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${saved.title} was created.')));
  }

  static void _leave(BuildContext context, Experience experience, String said) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(said)));
    Navigator.of(context).pop(experience);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.notifier});

  final ExperienceDetailNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final Experience? experience = notifier.isCreating
        ? null
        : notifier.experience;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(
              notifier.hasCreated || notifier.coverMayHaveChanged
                  ? notifier.experience
                  : null,
            ),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to the list',
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  experience?.title ?? 'New experience',
                  style: text.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (experience != null)
                  Text(
                    '${experience.cityName} · '
                    '${AppDurations.inWords(experience.durationMinutes)} · '
                    'hosted by ${experience.hostName}',
                    style: text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (experience != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            StatusChip(
              ListingStatus.of(experience.isActive).label,
              tone: experience.isActive ? Tone.positive : Tone.neutral,
            ),
          ],
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: AppSizes.hairline),
        ),
      ),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorColor: AppColors.indigo,
        labelColor: AppColors.indigoDeep,
        unselectedLabelColor: AppColors.inkMuted,
        labelStyle: Theme.of(context).textTheme.labelLarge,
        tabs: <Widget>[for (final _Hanging tab in _tabs) Tab(text: tab.label)],
      ),
    );
  }
}

class _Unready extends StatelessWidget {
  const _Unready({required this.gap});

  final String gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to the list',
            ),
          ),
        ),
        Expanded(
          child: EmptyState(
            title: 'Nothing to build an experience on',
            message:
                'An experience needs $gap, and there is not one yet. Add one '
                'under Reference data first.',
          ),
        ),
      ],
    );
  }
}

class _NotHereYet extends StatelessWidget {
  const _NotHereYet({required this.tab, required this.isCreating});

  final _Hanging tab;
  final bool isCreating;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: tab.label,
      message: isCreating
          ? 'An experience has to be created before ${tab.noun} can be managed.'
          : '${tab.label} are not managed here yet.',
    );
  }
}

@immutable
class _Hanging {
  const _Hanging(this.label, this.noun);

  final String label;
  final String noun;
}

const List<_Hanging> _tabs = <_Hanging>[
  _Hanging('Details', 'the details'),
  _Hanging('Photos', 'photographs'),
  _Hanging('Terms', 'terms'),
];
