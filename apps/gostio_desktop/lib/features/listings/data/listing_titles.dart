import '../../../core/network/api_client.dart';
import '../../../core/paging/page_walk.dart';
import '../../reference/data/lookup_item.dart';
import 'listing_address.dart';

// Both catalogues answer a title where a reference table answers a name, and
// a filter that names a listing wants nothing else off the row. Written once
// for the two of them, because the two answer the same shape.
Future<List<LookupItem>> readListingTitles(
  ApiClient client,
  ListingKind kind, {
  int? hostId,
}) => readEveryPage<LookupItem>(
  client,
  kind.root,
  read: (JsonMap json) => LookupItem(
    id: (json['id'] as num).toInt(),
    name: json['title'] as String,
  ),
  query: <String, dynamic>{'hostId': ?hostId},
);
