import 'package:flutter/foundation.dart';

import '../../../core/models/user.dart';
import '../../reference/data/lookup_item.dart';
import '../../reference/data/reference_repository.dart';
import '../../users/data/users_repository.dart';

@immutable
class AccommodationFormOptions {
  const AccommodationFormOptions({
    required this.cities,
    required this.types,
    required this.categories,
    required this.countries,
    required this.hosts,
  });

  static const AccommodationFormOptions none = AccommodationFormOptions(
    cities: <LookupItem>[],
    types: <LookupItem>[],
    categories: <LookupItem>[],
    countries: <LookupItem>[],
    hosts: <User>[],
  );

  // The users and countries routes are the administrator's, so a host asks for
  // neither: it hosts its own listings and cannot add a city. The hosts are
  // read only where one is named, which is a listing being created.
  static Future<AccommodationFormOptions> load(
    ReferenceRepository reference,
    UsersRepository users, {
    required bool asAdministrator,
    required bool forCreating,
  }) async {
    final List<Object> answers = await Future.wait(<Future<Object>>[
      reference.cities(),
      reference.accommodationTypes(),
      reference.accommodationCategories(),
      asAdministrator
          ? reference.countriesHoldingCities()
          : _nothing<LookupItem>(),
      asAdministrator && forCreating ? users.hosts() : _nothing<User>(),
    ]);

    return AccommodationFormOptions(
      cities: answers[0] as List<LookupItem>,
      types: answers[1] as List<LookupItem>,
      categories: answers[2] as List<LookupItem>,
      countries: answers[3] as List<LookupItem>,
      hosts: answers[4] as List<User>,
    );
  }

  static Future<List<T>> _nothing<T>() async => List<T>.empty();

  final List<LookupItem> cities;
  final List<LookupItem> types;
  final List<LookupItem> categories;
  final List<LookupItem> countries;
  final List<User> hosts;

  AccommodationFormOptions withCity(LookupItem city) =>
      AccommodationFormOptions(
        cities: <LookupItem>[...cities, city],
        types: types,
        categories: categories,
        countries: countries,
        hosts: hosts,
      );

  // A create form does not open while one of the tables it draws from is
  // empty, and it names the one that is.
  String? missingFor({required bool asAdministrator}) => switch (this) {
    _ when types.isEmpty => 'an accommodation type',
    _ when categories.isEmpty => 'an accommodation category',
    _ when cities.isEmpty => 'a city',
    _ when asAdministrator && hosts.isEmpty => 'a host to give it to',
    _ => null,
  };
}
