import 'package:gostio_core/gostio_core.dart';

import 'filter_options.dart';

// Five lookup tables, asked for at once. They are independent of each other,
// so waiting for them one after another would spend five round trips on a
// screen that needs one.
class FilterOptionsRepository {
  const FilterOptionsRepository(this._client);

  final ApiClient _client;

  Future<FilterOptions> read() async {
    final List<List<LookupItem>> tables = await Future.wait(
      <Future<List<LookupItem>>>[
        _all('/cities'),
        _all('/accommodation-types'),
        _all('/accommodation-categories'),
        _all('/experience-categories'),
        _all('/amenities'),
      ],
    );

    return FilterOptions(
      cities: tables[0],
      stayTypes: tables[1],
      stayCategories: tables[2],
      experienceCategories: tables[3],
      amenities: tables[4],
    );
  }

  Future<List<LookupItem>> _all(String path) =>
      readEveryPage<LookupItem>(_client, path, read: LookupItem.fromJson);
}
