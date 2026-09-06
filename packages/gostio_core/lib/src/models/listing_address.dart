import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

enum ListingKind {
  @JsonValue(_accommodations)
  accommodation('/accommodations', _accommodations),
  @JsonValue(_experiences)
  experience('/experiences', _experiences);

  const ListingKind(this.root, this.catalogueName);

  static const String _accommodations = 'Accommodations';
  static const String _experiences = 'Experiences';

  final String root;

  // What the API calls this whole side of the catalogue, both where a request
  // names the side rather than a listing on it and where an answer says which
  // side a row came from.
  final String catalogueName;

  String get slug => root.substring(1);
}

@immutable
class ListingAddress {
  const ListingAddress(this.kind, this.id);

  final ListingKind kind;
  final int id;

  // The row itself, which every collection under it is written against.
  String get path => '${kind.root}/$id';

  String get photos => '$path/photos';

  // Saved by the account reading it. Both catalogues answer this one, which is
  // why it is here rather than beside the collections only a stay has.
  String get favorite => '$path/favorite';

  String photo(int photoId) => '$photos/$photoId';

  String photoContent(int photoId) => '${photo(photoId)}/content';

  @override
  bool operator ==(Object other) =>
      other is ListingAddress && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}
