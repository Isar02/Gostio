import '../../../core/models/image_upload.dart';
import '../../../core/network/api_client.dart';
import '../../../core/paging/page_walk.dart';
import 'listing_address.dart';
import 'listing_photo.dart';

class ListingPhotosRepository {
  const ListingPhotosRepository(this._client);

  static const String fileField = 'File';

  final ApiClient _client;

  Future<List<ListingPhoto>> forListing(ListingAddress listing) =>
      readEveryPage<ListingPhoto>(
        _client,
        listing.photos,
        read: ListingPhoto.fromJson,
      );

  Future<ListingPhoto> upload(
    ListingAddress listing,
    ImageUpload image,
  ) async => ListingPhoto.fromJson(
    await _client.postForm(listing.photos, file: image.underField(fileField)),
  );

  Future<ListingPhoto> setCover(ListingAddress listing, int photoId) async =>
      ListingPhoto.fromJson(
        await _client.put('${listing.photo(photoId)}/cover'),
      );

  Future<void> delete(ListingAddress listing, int photoId) =>
      _client.delete(listing.photo(photoId));
}
