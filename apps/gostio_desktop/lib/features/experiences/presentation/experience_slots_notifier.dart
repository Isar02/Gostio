import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../../../core/paging/writing_notifier.dart';
import '../data/experience_slot_query.dart';
import '../data/experience_slots_repository.dart';

class ExperienceSlotsNotifier
    extends PagedNotifier<ExperienceSlot, ExperienceSlotQuery>
    with WritingNotifier<ExperienceSlot, ExperienceSlotQuery> {
  ExperienceSlotsNotifier(this._slots, {required this.experienceId})
    : super(ExperienceSlotQuery(from: CalendarDays.today()));

  final ExperienceSlotsRepository _slots;

  final int experienceId;

  @override
  Future<PagedResult<ExperienceSlot>> fetch({
    required int page,
    required ExperienceSlotQuery query,
  }) =>
      _slots.search(experienceId, query: query, page: page, pageSize: pageSize);

  Future<WriteOutcome> add({
    required DateTime startTime,
    required int capacity,
  }) => write(
    () => _slots.add(experienceId, startTime: startTime, capacity: capacity),
  );

  Future<WriteOutcome> save(
    int slotId, {
    required int capacity,
    required bool isActive,
  }) => write(
    () => _slots.update(
      experienceId,
      slotId,
      capacity: capacity,
      isActive: isActive,
    ),
  );

  Future<WriteOutcome> remove(int slotId) =>
      write(() => _slots.delete(experienceId, slotId));
}
