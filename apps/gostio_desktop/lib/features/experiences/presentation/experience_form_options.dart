import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../reference/data/reference_repository.dart';
import '../../users/data/users_repository.dart';

@immutable
class ExperienceFormOptions {
  const ExperienceFormOptions({
    required this.cities,
    required this.categories,
    required this.countries,
    required this.hosts,
  });

  static const ExperienceFormOptions none = ExperienceFormOptions(
    cities: <LookupItem>[],
    categories: <LookupItem>[],
    countries: <LookupItem>[],
    hosts: <User>[],
  );

  // The users and countries routes are the administrator's, so a host asks for
  // neither: it hosts its own experiences and cannot add a city. The hosts are
  // read only where one is named, which is an experience being created.
  static Future<ExperienceFormOptions> load(
    ReferenceRepository reference,
    UsersRepository users, {
    required bool asAdministrator,
    required bool forCreating,
  }) async {
    final List<Object> answers = await Future.wait(<Future<Object>>[
      reference.cities(),
      reference.experienceCategories(),
      asAdministrator
          ? reference.countriesHoldingCities()
          : _nothing<LookupItem>(),
      asAdministrator && forCreating ? users.hosts() : _nothing<User>(),
    ]);

    return ExperienceFormOptions(
      cities: answers[0] as List<LookupItem>,
      categories: answers[1] as List<LookupItem>,
      countries: answers[2] as List<LookupItem>,
      hosts: answers[3] as List<User>,
    );
  }

  static Future<List<T>> _nothing<T>() async => List<T>.empty();

  final List<LookupItem> cities;
  final List<LookupItem> categories;
  final List<LookupItem> countries;
  final List<User> hosts;

  ExperienceFormOptions withCity(LookupItem city) => ExperienceFormOptions(
    cities: <LookupItem>[...cities, city],
    categories: categories,
    countries: countries,
    hosts: hosts,
  );

  // A create form does not open while one of the tables it draws from is
  // empty, and it names the one that is.
  String? missingFor({required bool asAdministrator}) => switch (this) {
    _ when categories.isEmpty => 'an experience category',
    _ when cities.isEmpty => 'a city',
    _ when asAdministrator && hosts.isEmpty => 'a host to give it to',
    _ => null,
  };
}
