import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/explore/data/filter_options.dart';

// Rows of both catalogues the way the API answers them. A test names only what
// it is about; the rest is a plausible row from the seed.
Accommodation stay({
  int id = 1,
  String title = 'Loft over the river',
  String cityName = 'Mostar',
  String accommodationTypeName = 'Apartment',
  double pricePerNight = 90,
  int maxGuests = 4,
  double? averageRating = 4.5,
  int reviewCount = 12,
  bool isActive = true,
}) => Accommodation(
  id: id,
  hostId: 7,
  hostName: 'Amir Hodžić',
  title: title,
  description: 'Two rooms and a balcony over the water.',
  accommodationTypeId: 1,
  accommodationTypeName: accommodationTypeName,
  accommodationCategoryId: 2,
  accommodationCategoryName: 'City break',
  cityId: 3,
  cityName: cityName,
  countryName: 'Bosnia and Herzegovina',
  address: 'Maršala Tita 14',
  latitude: 43.34,
  longitude: 17.81,
  maxGuests: maxGuests,
  bedrooms: 2,
  bathrooms: 1,
  pricePerNight: pricePerNight,
  cleaningFee: 15,
  isActive: isActive,
  reviewCount: reviewCount,
  createdAt: DateTime.utc(2026, 4, 2, 9),
  averageRating: averageRating,
);

Experience experience({
  int id = 1,
  String title = 'Old town walk',
  String cityName = 'Sarajevo',
  String experienceCategoryName = 'Walking tour',
  double pricePerPerson = 25,
  int durationMinutes = 180,
  double? averageRating = 4.8,
  int reviewCount = 30,
  bool isActive = true,
}) => Experience(
  id: id,
  hostId: 9,
  hostName: 'Lejla Kovač',
  title: title,
  description: 'Three hours through the old quarter.',
  experienceCategoryId: 4,
  experienceCategoryName: experienceCategoryName,
  cityId: 1,
  cityName: cityName,
  countryName: 'Bosnia and Herzegovina',
  meetingPoint: 'Sebilj',
  latitude: 43.85,
  longitude: 18.43,
  durationMinutes: durationMinutes,
  pricePerPerson: pricePerPerson,
  isActive: isActive,
  reviewCount: reviewCount,
  createdAt: DateTime.utc(2026, 4, 4, 9),
  averageRating: averageRating,
);

// A few rows of each lookup table, which is all a sheet needs to be drawn.
FilterOptions filterOptions() => const FilterOptions(
  cities: <LookupItem>[
    LookupItem(id: 1, name: 'Sarajevo'),
    LookupItem(id: 3, name: 'Mostar'),
  ],
  stayTypes: <LookupItem>[
    LookupItem(id: 1, name: 'Apartment'),
    LookupItem(id: 2, name: 'House'),
  ],
  stayCategories: <LookupItem>[
    LookupItem(id: 2, name: 'City break'),
    LookupItem(id: 5, name: 'Mountain'),
  ],
  experienceCategories: <LookupItem>[
    LookupItem(id: 4, name: 'Walking tour'),
    LookupItem(id: 6, name: 'Food'),
  ],
  amenities: <LookupItem>[
    LookupItem(id: 1, name: 'Wi-Fi'),
    LookupItem(id: 2, name: 'Parking'),
  ],
);
