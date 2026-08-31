import '../../../core/network/api_client.dart';
import '../../../core/paging/page_walk.dart';
import '../../reference/data/lookup_item.dart';

class AccommodationAmenitiesRepository {
  const AccommodationAmenitiesRepository(this._client);

  static const String idsField = 'amenityIds';

  final ApiClient _client;

  Future<List<LookupItem>> forAccommodation(int accommodationId) =>
      readEveryPage<LookupItem>(
        _client,
        _path(accommodationId),
        read: LookupItem.fromJson,
      );

  // The write answers with the whole set it has just stored rather than a page
  // of it, so what comes back is read instead of asking for the set again.
  Future<List<LookupItem>> set(
    int accommodationId,
    List<int> amenityIds,
  ) async {
    final List<dynamic> written = await _client.putList(
      _path(accommodationId),
      body: <String, dynamic>{idsField: amenityIds},
    );

    return <LookupItem>[
      for (final dynamic offered in written)
        LookupItem.fromJson(offered! as JsonMap),
    ];
  }

  static String _path(int accommodationId) =>
      '/accommodations/$accommodationId/amenities';
}
