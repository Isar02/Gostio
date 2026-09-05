import 'dart:async';

import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/live_notifier.dart';
import '../data/listing_detail.dart';
import '../data/listing_repository.dart';
import 'favorite_edits.dart';

// One listing's screen: the row and the collections under it, landed together,
// and the heart in the bar, which is the only thing here that writes.
//
// The heart is held apart from the row it was read from. A listing is read
// once and the heart is answered every time it is pressed, so what the server
// last accepted is what it draws rather than what the row said on arrival.
class ListingDetailNotifier extends LiveNotifier {
  ListingDetailNotifier(this._repository, this._edits, this.address) {
    unawaited(load());
  }

  final ListingRepository _repository;
  final FavoriteEdits _edits;
  final ListingAddress address;

  ListingOverview? _overview;
  bool _isLoading = false;
  ApiException? _failure;
  bool _isFavorite = false;
  bool _isSavingFavorite = false;
  ApiException? _favoriteFailure;

  ListingOverview? get overview => _overview;

  bool get isLoading => _isLoading;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  bool get isFavorite => _isFavorite;

  bool get isSavingFavorite => _isSavingFavorite;

  String? get favoriteRefusal => _favoriteFailure?.message;

  Future<void> load() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _failure = null;
    publish();

    try {
      final ListingOverview read = await _repository.read(address);
      _overview = read;
      // What this reader has already done outranks the row, which the server
      // wrote before the heart was touched.
      _isFavorite = _edits.of(address) ?? read.detail.isFavorite;
    } on ApiException catch (refused) {
      _failure = refused;
    }

    _isLoading = false;
    publish();
  }

  // Answers whether the listing is saved now. The heart turns only once the
  // server has accepted it: a heart that fills and empties again says the
  // client was guessing.
  Future<bool> toggleFavorite() async {
    if (_isSavingFavorite) {
      return false;
    }

    final bool wanted = !_isFavorite;

    _isSavingFavorite = true;
    _favoriteFailure = null;
    publish();

    try {
      await (wanted
          ? _repository.addFavorite(address)
          : _repository.removeFavorite(address));
      _isFavorite = wanted;
      // The list this screen was opened from still holds the row as it was
      // read, so what was written here is recorded where that list looks.
      _edits.record(address, isFavorite: wanted);
    } on ApiException catch (refused) {
      _favoriteFailure = refused;
    }

    _isSavingFavorite = false;
    publish();

    return _favoriteFailure == null;
  }
}
