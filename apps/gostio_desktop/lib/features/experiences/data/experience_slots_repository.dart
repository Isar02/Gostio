import '../../../core/models/paged_result.dart';
import '../../../core/network/api_client.dart';
import 'experience_slot.dart';
import 'experience_slot_query.dart';

class ExperienceSlotsRepository {
  const ExperienceSlotsRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<ExperienceSlot>> search(
    int experienceId, {
    required ExperienceSlotQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    final JsonMap body = await _client.get(
      _path(experienceId),
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        ...query.toParameters(),
      },
    );

    return PagedResult<ExperienceSlot>.fromJson(
      body,
      (Object? item) => ExperienceSlot.fromJson(item! as JsonMap),
    );
  }

  // The duration is the experience's own, so a term is created from when it
  // starts and how many it takes; the server works out when it ends.
  Future<ExperienceSlot> add(
    int experienceId, {
    required DateTime startTime,
    required int capacity,
  }) async => ExperienceSlot.fromJson(
    await _client.post(
      _path(experienceId),
      body: <String, dynamic>{
        'startTime': startTime.toUtc().toIso8601String(),
        'capacity': capacity,
      },
    ),
  );

  Future<ExperienceSlot> update(
    int experienceId,
    int slotId, {
    required int capacity,
    required bool isActive,
  }) async => ExperienceSlot.fromJson(
    await _client.put(
      '${_path(experienceId)}/$slotId',
      body: <String, dynamic>{'capacity': capacity, 'isActive': isActive},
    ),
  );

  Future<void> delete(int experienceId, int slotId) =>
      _client.delete('${_path(experienceId)}/$slotId');

  static String _path(int experienceId) => '/experiences/$experienceId/slots';
}
