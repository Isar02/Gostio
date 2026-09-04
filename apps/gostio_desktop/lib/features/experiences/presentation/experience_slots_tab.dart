import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/pagination_footer.dart';
import '../../../core/widgets/record_table.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../reservations/data/reservations_repository.dart';
import '../data/experience_slot_query.dart';
import '../data/experience_slots_repository.dart';
import 'experience_slot_dialog.dart';
import 'experience_slots_notifier.dart';
import 'new_experience_slot_dialog.dart';
import 'slot_status.dart';

class ExperienceSlotsTab extends StatelessWidget {
  const ExperienceSlotsTab({
    required this.experienceId,
    required this.durationMinutes,
    super.key,
  });

  final int experienceId;
  final int durationMinutes;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ExperienceSlotsNotifier>(
      create: (BuildContext context) {
        final ExperienceSlotsNotifier slots = ExperienceSlotsNotifier(
          context.read<ExperienceSlotsRepository>(),
          experienceId: experienceId,
        );
        unawaited(slots.reload());

        return slots;
      },
      child: _Terms(durationMinutes: durationMinutes),
    );
  }
}

class _Terms extends StatelessWidget {
  const _Terms({required this.durationMinutes});

  final int durationMinutes;

  @override
  Widget build(BuildContext context) {
    final ExperienceSlotsNotifier slots = context
        .watch<ExperienceSlotsNotifier>();
    final String? failure = slots.failureMessage;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Window(
            slots: slots,
            onAdd: () => _add(context, slots, durationMinutes),
          ),
          if (slots.isStale) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _Behind(slots: slots),
          ] else if (failure != null && slots.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(failure),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSizes.stroke,
            child: slots.isLoading ? const LinearProgressIndicator() : null,
          ),
          Expanded(
            child: RecordTable<ExperienceSlot>(
              columns: _columns,
              rows: slots.items,
              onRowOpen: slots.isStale
                  ? null
                  : (ExperienceSlot row) => _open(context, slots, row),
              empty: _Nothing(slots: slots),
              footer: PaginationFooter(
                page: slots.page,
                pageSize: slots.pageSize,
                totalCount: slots.totalCount,
                onPageChanged: slots.openPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _add(
    BuildContext context,
    ExperienceSlotsNotifier slots,
    int durationMinutes,
  ) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => NewExperienceSlotDialog(
      durationMinutes: durationMinutes,
      add: ({required DateTime startTime, required int capacity}) =>
          slots.add(startTime: startTime, capacity: capacity),
    ),
  );

  static Future<void> _open(
    BuildContext context,
    ExperienceSlotsNotifier slots,
    ExperienceSlot slot,
  ) {
    final ReservationsRepository reservations = context
        .read<ReservationsRepository>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => ExperienceSlotDialog(
        slot: slot,
        save: ({required int capacity, required bool isActive}) =>
            slots.save(slot.id, capacity: capacity, isActive: isActive),
        remove: () => slots.remove(slot.id),
        countReservations: () => reservations.countForSlot(slot.id),
      ),
    );
  }
}

class _Window extends StatelessWidget {
  const _Window({required this.slots, required this.onAdd});

  final ExperienceSlotsNotifier slots;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ExperienceSlotQuery window = slots.query;

    return FilterBar(
      onClear: () => slots.apply(const ExperienceSlotQuery()),
      trailing: FilledButton.icon(
        onPressed: slots.isWriting || slots.isStale ? null : onAdd,
        icon: const Icon(Icons.add, size: AppSizes.iconSmall),
        label: const Text('Add term'),
      ),
      filters: <Widget>[
        FilterField(
          label: 'From',
          width: AppSizes.filterField,
          child: DateField(
            value: window.from,
            hint: 'The first term',
            onChanged: (DateTime? from) => slots.apply(
              ExperienceSlotQuery(
                from: from,
                to: window.to,
                isActive: window.isActive,
              ),
            ),
          ),
        ),
        FilterField(
          label: 'To',
          width: AppSizes.filterField,
          child: DateField(
            value: window.to,
            hint: 'The last term',
            onChanged: (DateTime? to) => slots.apply(
              ExperienceSlotQuery(
                from: window.from,
                to: to,
                isActive: window.isActive,
              ),
            ),
          ),
        ),
        FilterField(
          label: 'Status',
          child: AppDropdown<SlotStatus>(
            value: SlotStatus.values.firstWhere(
              (SlotStatus status) => status.isActive == window.isActive,
            ),
            values: SlotStatus.values,
            labels: (SlotStatus status) => status.label,
            onChanged: (SlotStatus status) => slots.apply(
              ExperienceSlotQuery(
                from: window.from,
                to: window.to,
                isActive: status.isActive,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// What the availability calendar already settled: a page older than the
// server offers the read again rather than more writes over what it holds.
class _Behind extends StatelessWidget {
  const _Behind({required this.slots});

  final ExperienceSlotsNotifier slots;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: AppNotice(
            'A term was written, and the terms could not be read back. This '
            'page is behind what the server holds, so nothing more is written '
            'from it.',
            tone: Tone.attention,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        OutlinedButton(
          onPressed: slots.isLoading ? null : slots.reload,
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.slots});

  final ExperienceSlotsNotifier slots;

  @override
  Widget build(BuildContext context) {
    if (slots.isLoading) {
      return const LoadingState();
    }

    if (slots.failureMessage case final String failure) {
      return ErrorState(
        message: failure,
        onRetry: slots.reload,
        traceId: slots.failureTraceId,
      );
    }

    return slots.query.isEmpty
        ? const EmptyState(
            title: 'No terms yet',
            message:
                'A term is one running of this experience: when it starts and '
                'how many places it takes. Add the first one.',
          )
        : const EmptyState(
            title: 'No terms in this window',
            message: 'Nothing runs between the two days set above.',
          );
  }
}

final List<TableColumn<ExperienceSlot>> _columns =
    <TableColumn<ExperienceSlot>>[
      TableColumn<ExperienceSlot>.text(
        label: 'Starts',
        read: (ExperienceSlot row) => AppDates.dateTime(row.startTime),
        flex: 2,
      ),
      TableColumn<ExperienceSlot>.text(
        label: 'Ends',
        read: (ExperienceSlot row) => AppDates.time(row.endTime),
        width: AppSizes.compactColumn,
      ),
      TableColumn<ExperienceSlot>.text(
        label: 'Runs for',
        read: (ExperienceSlot row) => AppDurations.inWords(row.durationMinutes),
        width: AppSizes.numericColumn,
      ),
      TableColumn<ExperienceSlot>.number(
        label: 'Places',
        read: (ExperienceSlot row) => '${row.capacity}',
        width: AppSizes.compactColumn,
      ),
      TableColumn<ExperienceSlot>.number(
        label: 'Booked',
        read: (ExperienceSlot row) => '${row.bookedCapacity}',
        width: AppSizes.compactColumn,
      ),
      TableColumn<ExperienceSlot>.number(
        label: 'Free',
        read: (ExperienceSlot row) => '${row.remainingCapacity}',
        width: AppSizes.compactColumn,
      ),
      TableColumn<ExperienceSlot>(
        label: 'Status',
        width: AppSizes.statusColumn,
        cell: (BuildContext context, ExperienceSlot row) => StatusChip(
          SlotStatus.of(row.isActive).label,
          tone: row.isActive ? Tone.positive : Tone.neutral,
        ),
      ),
    ];
