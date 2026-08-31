import '../../../core/models/image_upload.dart';
import '../../../core/network/api_client.dart';
import '../../../core/paging/page_walk.dart';
import 'accommodation_photo.dart';

class AccommodationPhotosRepository {
  const AccommodationPhotosRepository(this._client);

  static const String fileField = 'File';

  final ApiClient _client;

  Future<List<AccommodationPhoto>> forAccommodation(int accommodationId) =>
      readEveryPage<AccommodationPhoto>(
        _client,
        _path(accommodationId),
        read: AccommodationPhoto.fromJson,
      );

  Future<AccommodationPhoto> upload(
    int accommodationId,
    ImageUpload image,
  ) async => AccommodationPhoto.fromJson(
    await _client.upload(
      _path(accommodationId),
      field: fileField,
      name: image.name,
      bytes: image.bytes,
      contentType: image.contentType,
    ),
  );

  Future<AccommodationPhoto> setCover(int accommodationId, int photoId) async =>
      AccommodationPhoto.fromJson(
        await _client.put('${_path(accommodationId)}/$photoId/cover'),
      );

  Future<void> delete(int accommodationId, int photoId) =>
      _client.delete('${_path(accommodationId)}/$photoId');

  static String _path(int accommodationId) =>
      '/accommodations/$accommodationId/photos';
}
