import 'package:json_annotation/json_annotation.dart';

part 'accommodation_photo.g.dart';

@JsonSerializable(createToJson: false)
class AccommodationPhoto {
  const AccommodationPhoto({
    required this.id,
    required this.listingId,
    required this.contentType,
    required this.isCover,
    required this.displayOrder,
    required this.sizeInBytes,
    required this.uploadedAt,
  });

  factory AccommodationPhoto.fromJson(Map<String, dynamic> json) =>
      _$AccommodationPhotoFromJson(json);

  final int id;
  final int listingId;
  final String contentType;
  final bool isCover;
  final int displayOrder;
  final int sizeInBytes;
  final DateTime uploadedAt;

  String get contentPath => '/accommodations/$listingId/photos/$id/content';
}
