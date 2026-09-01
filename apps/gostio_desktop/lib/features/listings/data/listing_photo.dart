import 'package:json_annotation/json_annotation.dart';

part 'listing_photo.g.dart';

// Where the bytes are fetched from is the listing's own address rather than a
// column here, because one response answers for both catalogues.
@JsonSerializable(createToJson: false)
class ListingPhoto {
  const ListingPhoto({
    required this.id,
    required this.listingId,
    required this.contentType,
    required this.isCover,
    required this.displayOrder,
    required this.sizeInBytes,
    required this.uploadedAt,
  });

  factory ListingPhoto.fromJson(Map<String, dynamic> json) =>
      _$ListingPhotoFromJson(json);

  final int id;
  final int listingId;
  final String contentType;
  final bool isCover;
  final int displayOrder;
  final int sizeInBytes;
  final DateTime uploadedAt;
}
