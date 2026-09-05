import 'package:gostio_core/gostio_core.dart';

import 'experience_filters.dart';
import 'stay_filters.dart';

// The two catalogues a guest browses. They are read here together because one
// screen holds both, and apart from each other because a stay and a term are
// different rows answered by different routes.
class CatalogueRepository {
  const CatalogueRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<Accommodation>> stays({
    required StayFilters filters,
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      '/accommodations',
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        ...filters.toParameters(),
      },
    );

    return PagedResult<Accommodation>.fromJson(
      body,
      (Object? item) => Accommodation.fromJson(item! as JsonMap),
    );
  }

  Future<PagedResult<Experience>> experiences({
    required ExperienceFilters filters,
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      '/experiences',
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        ...filters.toParameters(),
      },
    );

    return PagedResult<Experience>.fromJson(
      body,
      (Object? item) => Experience.fromJson(item! as JsonMap),
    );
  }
}
