import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/page_walk.dart';
import 'availability_draft.dart';

class AccommodationAvailabilityRepository {
  const AccommodationAvailabilityRepository(this._client);

  final ApiClient _client;

  // An entry reaching past either edge of the window still answers to it, so
  // what comes back covers every day the grid draws rather than only the ones
  // that begin inside it.
  Future<List<AccommodationAvailability>> forWindow(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) => readEveryPage<AccommodationAvailability>(
    _client,
    _path(accommodationId),
    read: AccommodationAvailability.fromJson,
    query: <String, dynamic>{
      'from': CalendarDays.write(from),
      'to': CalendarDays.write(to),
    },
  );

  Future<AccommodationAvailability> add(
    int accommodationId,
    AvailabilityDraft draft,
  ) async => AccommodationAvailability.fromJson(
    await _client.post(_path(accommodationId), body: draft.toJson()),
  );

  Future<void> delete(int accommodationId, int availabilityId) =>
      _client.delete('${_path(accommodationId)}/$availabilityId');

  static String _path(int accommodationId) =>
      '/accommodations/$accommodationId/availability';
}
