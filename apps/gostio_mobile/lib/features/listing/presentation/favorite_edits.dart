import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// What this reader has saved and unsaved since a list was read. A card carries
// the state the server answered with when its page arrived, so a heart turned
// on a listing's own screen would otherwise come back to a card still saying
// the opposite of what the reader just did.
//
// Only writes the server accepted are recorded here. Nothing in it is a guess
// about a call that is still out.
class FavoriteEdits extends ChangeNotifier {
  final Map<ListingAddress, bool> _saved = <ListingAddress, bool>{};

  bool? of(ListingAddress address) => _saved[address];

  void record(ListingAddress address, {required bool isFavorite}) {
    _saved[address] = isFavorite;
    notifyListeners();
  }
}
