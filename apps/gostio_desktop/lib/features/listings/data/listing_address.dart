import 'package:flutter/foundation.dart';

enum ListingKind {
  accommodation('/accommodations'),
  experience('/experiences');

  const ListingKind(this.root);

  final String root;
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
