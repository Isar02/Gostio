import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../../listing/presentation/favorite_edits.dart';
import '../data/favorites_repository.dart';

// What this account has kept, newest first. The account is the whole query, so
// the paging carries nothing of its own.
//
// The heart is turned on a listing's own screen rather than on a row here, so
// this listens to what those screens have written: a listing unsaved on the
// screen this list opened leaves the list without the list being read again.
// A listing saved somewhere else is not put in — where it belongs in the order
// is the server's to say, and a pull is what asks it.
class FavoritesNotifier extends PagedNotifier<Favorite, void> {
  FavoritesNotifier(this._favorites, this._edits) : super(null) {
    _edits.addListener(_dropWhatWasUnsaved);
    unawaited(reload());
  }

  final FavoritesRepository _favorites;
  final FavoriteEdits _edits;

  @override
  void dispose() {
    _edits.removeListener(_dropWhatWasUnsaved);

    super.dispose();
  }

  @override
  @protected
  Future<PagedResult<Favorite>> fetch({
    required int page,
    required void query,
  }) => _favorites.saved(page: page, pageSize: pageSize);

  void _dropWhatWasUnsaved() => removeWhere(_wasUnsaved);

  bool _wasUnsaved(Favorite saved) => switch (saved.listing) {
    final ListingAddress address => _edits.of(address) == false,
    null => false,
  };
}
