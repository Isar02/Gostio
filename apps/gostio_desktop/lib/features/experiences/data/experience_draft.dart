import '../../../core/network/api_client.dart';

// The experience's own fields as the form holds them. Create and edit are one
// form, so one draft answers both endpoints: a host is named only where an
// administrator creates for somebody else, and the published flag only where
// an experience already exists — a new one is published by the API on its own.
class ExperienceDraft {
  const ExperienceDraft({
    required this.title,
    required this.description,
    required this.experienceCategoryId,
    required this.cityId,
    required this.meetingPoint,
    required this.latitude,
    required this.longitude,
    required this.durationMinutes,
    required this.pricePerPerson,
  });

  final String title;
  final String description;
  final int experienceCategoryId;
  final int cityId;
  final String meetingPoint;
  final double latitude;
  final double longitude;
  final int durationMinutes;
  final double pricePerPerson;

  JsonMap toCreate({int? hostId}) => <String, dynamic>{
    ..._fields,
    'hostId': ?hostId,
  };

  JsonMap toUpdate({required bool isActive}) => <String, dynamic>{
    ..._fields,
    'isActive': isActive,
  };

  JsonMap get _fields => <String, dynamic>{
    'title': title,
    'description': description,
    'experienceCategoryId': experienceCategoryId,
    'cityId': cityId,
    'meetingPoint': meetingPoint,
    'latitude': latitude,
    'longitude': longitude,
    'durationMinutes': durationMinutes,
    'pricePerPerson': pricePerPerson,
  };
}
