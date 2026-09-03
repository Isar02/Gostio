import 'package:flutter/foundation.dart';

enum ListingKind {
  accommodation('/accommodations', 'Accommodations'),
  experience('/experiences', 'Experiences');

  const ListingKind(this.root, this.catalogueName);

  final String root;

  // What the API calls this whole side of the catalogue, where a request names
  // the side rather than a listing on it.
  final String catalogueName;

  String get slug => root.substring(1);
}

@immutable
class ListingAddress {
  const ListingAddress(this.kind, this.id);

  final ListingKind kind;
  final int id;

  String get photos => '${kind.root}/$id/photos';

  String photo(int photoId) => '$photos/$photoId';

  String photoContent(int photoId) => '${photo(photoId)}/content';

  @override
  bool operator ==(Object other) =>
      other is ListingAddress && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}
