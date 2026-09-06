import 'package:gostio_core/gostio_core.dart';

// Why a listing is on this screen, in words. The server answers a kind and the
// value it matched and leaves the sentence to the client, because the client
// is the side that knows what language it speaks.
//
// A reason is written as a sentence rather than drawn as an icon: an icon
// standing for *priced near what you usually pay* has to be learned before it
// says anything, and the reasons are the whole point of this screen.
//
// Three sentences are as many as one card carries — the server sends at most
// three — so nothing here shortens or ranks them.
List<String> reasonsInWords(Recommendation picked) => <String>[
  for (final RecommendationReason reason in picked.reasons)
    if (_worded(reason) case final String words) words,
];

// A kind that names a value says nothing without one, and a kind this build
// does not know says nothing at all: a sentence built around a word the client
// cannot read would be the one thing this screen must not get wrong.
String? _worded(RecommendationReason reason) => switch (reason.kind) {
  RecommendationReasonKind.city => _about(
    reason,
    (String city) => 'In $city, where you have been looking',
  ),
  RecommendationReasonKind.category => _about(
    reason,
    (String category) => '$category, like the ones you go for',
  ),
  RecommendationReasonKind.accommodationType => _about(
    reason,
    (String type) => '$type, the kind you tend to book',
  ),
  RecommendationReasonKind.amenity => _about(
    reason,
    (String amenity) => 'Has $amenity, which you look for',
  ),
  RecommendationReasonKind.term => _about(
    reason,
    (String term) => 'Matches “$term” from what you have searched',
  ),
  RecommendationReasonKind.price => 'Priced near what you usually pay',
  RecommendationReasonKind.capacity => 'Room for the party you book for',
  RecommendationReasonKind.rating => _about(
    reason,
    (String rating) => switch (double.tryParse(rating)) {
      final double value =>
        'Rated ${AppNumbers.rating(value)}, above average here',
      null => null,
    },
  ),
  // The one reason whose value is a figure rather than a name. A count that
  // is not a figure is a value this client cannot read, which is the same
  // case as a kind it cannot read.
  RecommendationReasonKind.popularity => _about(
    reason,
    (String count) => switch (int.tryParse(count)) {
      final int times => 'Kept or booked ${AppNumbers.counted(times, 'time')}',
      null => null,
    },
  ),
  RecommendationReasonKind.onOffer =>
    'On offer, and not picked from anything you have done',
  RecommendationReasonKind.unknown => null,
};

String? _about(
  RecommendationReason reason,
  String? Function(String detail) words,
) => switch (reason.detail) {
  final String detail when detail.isNotEmpty => words(detail),
  _ => null,
};
