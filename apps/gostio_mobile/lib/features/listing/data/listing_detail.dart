import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// One listing of either catalogue, read as one shape. A stay and a term are
// different rows answered by different routes, and a guest reads them on the
// same screen: what they have in common is named here, and what only one of
// them carries is asked for by the section that draws it.
@immutable
sealed class ListingDetail {
  const ListingDetail();

  ListingAddress get address;

  String get title;

  String get description;

  String get hostName;

  String get cityName;

  String get countryName;

  // The street or the meeting point: what the pin on the map is standing on.
  String get where;

  double get latitude;

  double get longitude;

  // What the server charges for one of whatever this listing is sold by. The
  // client renders this figure and never works one out.
  double get price;

  String get priceUnit;

  double? get averageRating;

  int get reviewCount;

  bool get isFavorite;

  String get place => '$cityName, $countryName';
}

final class StayDetail extends ListingDetail {
  const StayDetail(this.stay);

  final Accommodation stay;

  @override
  ListingAddress get address =>
      ListingAddress(ListingKind.accommodation, stay.id);

  @override
  String get title => stay.title;

  @override
  String get description => stay.description;

  @override
  String get hostName => stay.hostName;

  @override
  String get cityName => stay.cityName;

  @override
  String get countryName => stay.countryName;

  @override
  String get where => stay.address;

  @override
  double get latitude => stay.latitude;

  @override
  double get longitude => stay.longitude;

  @override
  double get price => stay.pricePerNight;

  @override
  String get priceUnit => 'per night';

  @override
  double? get averageRating => stay.averageRating;

  @override
  int get reviewCount => stay.reviewCount;

  @override
  bool get isFavorite => stay.isFavorite;
}

final class ExperienceDetail extends ListingDetail {
  const ExperienceDetail(this.experience);

  final Experience experience;

  @override
  ListingAddress get address =>
      ListingAddress(ListingKind.experience, experience.id);

  @override
  String get title => experience.title;

  @override
  String get description => experience.description;

  @override
  String get hostName => experience.hostName;

  @override
  String get cityName => experience.cityName;

  @override
  String get countryName => experience.countryName;

  @override
  String get where => experience.meetingPoint;

  @override
  double get latitude => experience.latitude;

  @override
  double get longitude => experience.longitude;

  @override
  double get price => experience.pricePerPerson;

  @override
  String get priceUnit => 'per person';

  @override
  double? get averageRating => experience.averageRating;

  @override
  int get reviewCount => experience.reviewCount;

  @override
  bool get isFavorite => experience.isFavorite;
}

// What one listing's screen opens on: the row and the collections that belong
// to it. They are read together because the screen is drawn from all of them
// at once, and a term has no amenities, so that collection arrives empty.
@immutable
class ListingOverview {
  const ListingOverview({
    required this.detail,
    required this.photos,
    required this.amenities,
  });

  final ListingDetail detail;
  final List<ListingPhoto> photos;
  final List<LookupItem> amenities;
}
