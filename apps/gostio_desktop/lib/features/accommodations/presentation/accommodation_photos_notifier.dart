import 'package:flutter/foundation.dart';

import '../../../core/models/image_upload.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/screen_notifier.dart';
import '../data/accommodation_photo.dart';
import '../data/accommodation_photos_repository.dart';

class AccommodationPhotosNotifier extends ScreenNotifier {
  AccommodationPhotosNotifier(
    this._photos, {
    required this.accommodationId,
    required this.onCoverMayChange,
  });

  final AccommodationPhotosRepository _photos;

  final int accommodationId;

  final VoidCallback onCoverMayChange;

  bool _isLoading = true;
  int _chosen = 0;
  int _uploaded = 0;
  int? _busyPhotoId;
  List<AccommodationPhoto> _items = const <AccommodationPhoto>[];
  ApiException? _failure;
  String? _refusal;

  bool get isLoading => _isLoading;

  bool get isUploading => _chosen > 0;

  bool get isBusy => isUploading || _busyPhotoId != null;

  int get chosen => _chosen;

  int get uploading => _uploaded < _chosen ? _uploaded + 1 : _chosen;

  int? get busyPhotoId => _busyPhotoId;

  List<AccommodationPhoto> get items => _items;

  int get totalBytes => _items.fold(
    0,
    (int total, AccommodationPhoto photo) => total + photo.sizeInBytes,
  );

  String? get failureMessage =>
      _refusal ??
      _failure?.firstMessageFor(AccommodationPhotosRepository.fileField) ??
      _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  Future<void> load() async {
    _isLoading = true;
    _forget();
    publish();

    await _read();

    _isLoading = false;
    publish();
  }

  Future<void> add(List<ImageUpload> images) async {
    if (images.isEmpty) {
      return;
    }

    _forget();
    _chosen = images.length;
    _uploaded = 0;
    publish();

    bool coverMayChangeReported = false;
    for (final ImageUpload image in images) {
      if (image.refusal case final String refusal) {
        _refusal = '${image.name}: $refusal';
        break;
      }

      if (!_hasCover && !coverMayChangeReported) {
        onCoverMayChange();
        coverMayChangeReported = true;
      }

      try {
        await _photos.upload(accommodationId, image);
      } on ApiException catch (failure) {
        _failure = failure;
        break;
      }

      _uploaded++;
      publish();
    }

    if (_uploaded > 0) {
      await _read();
    }

    _chosen = 0;
    _uploaded = 0;
    publish();
  }

  Future<void> setCover(int photoId) {
    onCoverMayChange();

    return _writeThenReload(
      photoId,
      () => _photos.setCover(accommodationId, photoId),
    );
  }

  Future<void> remove(int photoId) {
    if (_items.any(
      (AccommodationPhoto photo) => photo.id == photoId && photo.isCover,
    )) {
      onCoverMayChange();
    }

    return _writeThenReload(
      photoId,
      () => _photos.delete(accommodationId, photoId),
    );
  }

  void refuse(String message) {
    _refusal = message;
    publish();
  }

  Future<void> _writeThenReload(
    int photoId,
    Future<void> Function() write,
  ) async {
    _forget();
    _busyPhotoId = photoId;
    publish();

    try {
      await write();
    } on ApiException catch (failure) {
      _failure = failure;
      _busyPhotoId = null;
      publish();

      return;
    }

    await _read();

    _busyPhotoId = null;
    publish();
  }

  Future<void> _read() async {
    try {
      _items = await _photos.forAccommodation(accommodationId);
    } on ApiException catch (failure) {
      _failure = failure;
    }
  }

  void _forget() {
    _failure = null;
    _refusal = null;
  }

  bool get _hasCover => _items.any((AccommodationPhoto photo) => photo.isCover);
}
