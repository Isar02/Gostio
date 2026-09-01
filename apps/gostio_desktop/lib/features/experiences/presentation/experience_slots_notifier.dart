import '../../../core/models/paged_result.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/time/calendar_days.dart';
import '../data/experience_slot.dart';
import '../data/experience_slot_query.dart';
import '../data/experience_slots_repository.dart';

// A write answers its refusal to the dialog that asked for it rather than
// leaving it on the tab: that dialog is what has to stay open and say so.
class ExperienceSlotsNotifier
    extends PagedNotifier<ExperienceSlot, ExperienceSlotQuery> {
  ExperienceSlotsNotifier(this._slots, {required this.experienceId})
    : super(ExperienceSlotQuery(from: CalendarDays.today()));

  final ExperienceSlotsRepository _slots;

  final int experienceId;

  bool _isWriting = false;
  bool _isStale = false;
  bool _writeAwaitsRead = false;

  bool get isWriting => _isWriting;

  // A write that stood over a read that did not leaves the rows on screen
  // older than the server. Nothing more is written from them until a read
  // succeeds: the row a dialog would be opened from is one the term no longer
  // has, and a closed term could be reopened from it.
  bool get isStale => _isStale;

  // Staleness is settled by the read that follows a write rather than by the
  // write: a read that lands puts the rows back in step, one that fails leaves
  // them behind it, and one that was overtaken settles nothing at all.
  @override
  void onLoaded({required bool landed}) {
    if (landed) {
      _writeAwaitsRead = false;
      _isStale = false;
    } else if (_writeAwaitsRead) {
      _isStale = true;
    }
  }

  @override
  Future<PagedResult<ExperienceSlot>> fetch({
    required int page,
    required ExperienceSlotQuery query,
  }) =>
      _slots.search(experienceId, query: query, page: page, pageSize: pageSize);

  Future<ApiException?> add({
    required DateTime startTime,
    required int capacity,
  }) => _write(
    () => _slots.add(experienceId, startTime: startTime, capacity: capacity),
  );

  Future<ApiException?> save(
    int slotId, {
    required int capacity,
    required bool isActive,
  }) => _write(
    () => _slots.update(
      experienceId,
      slotId,
      capacity: capacity,
      isActive: isActive,
    ),
  );

  Future<ApiException?> remove(int slotId) =>
      _write(() => _slots.delete(experienceId, slotId));

  Future<ApiException?> _write(Future<void> Function() write) async {
    _isWriting = true;
    publish();

    try {
      await write();
    } on ApiException catch (refused) {
      _isWriting = false;
      publish();

      return refused;
    }

    _isWriting = false;
    _writeAwaitsRead = true;
    await reload();

    return null;
  }
}
