enum ReferenceTable {
  countries('/countries', 'country', 'countries'),
  cities('/cities', 'city', 'cities'),
  accommodationTypes(
    '/accommodation-types',
    'accommodation type',
    'accommodation types',
  ),
  accommodationCategories(
    '/accommodation-categories',
    'accommodation category',
    'accommodation categories',
  ),
  experienceCategories(
    '/experience-categories',
    'experience category',
    'experience categories',
  ),
  amenities('/amenities', 'amenity', 'amenities'),
  roles('/roles', 'role', 'roles'),
  reservationStatuses(
    '/reservation-statuses',
    'reservation status',
    'reservation statuses',
  );

  const ReferenceTable(this.path, this.noun, this.plural);

  final String path;
  final String noun;
  final String plural;
}
