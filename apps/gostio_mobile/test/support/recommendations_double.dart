import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/recommendations/data/recommendations_repository.dart';

// What the server suggests, answered without a socket. Every request records
// the catalogue and the page it asked for, so a test says what the screen sent
// rather than reading it back off the screen.
class RecommendationsDouble implements RecommendationsRepository {
  RecommendationsDouble({
    this.stays = const <Recommendation>[],
    this.terms = const <Recommendation>[],
    this.failure,
  });

  final List<Recommendation> stays;
  final List<Recommendation> terms;
  final ApiException? failure;

  final List<({ListingKind catalogue, int page})> asked =
      <({ListingKind catalogue, int page})>[];

  @override
  Future<PagedResult<Recommendation>> picks({
    required ListingKind catalogue,
    required int page,
    required int pageSize,
  }) async {
    asked.add((catalogue: catalogue, page: page));

    if (failure case final ApiException refused) {
      throw refused;
    }

    final List<Recommendation> ranked = switch (catalogue) {
      ListingKind.accommodation => stays,
      ListingKind.experience => terms,
    };

    final int from = ((page - 1) * pageSize).clamp(0, ranked.length);
    final int to = (from + pageSize).clamp(0, ranked.length);

    return PagedResult<Recommendation>(
      items: ranked.sublist(from, to),
      page: page,
      pageSize: pageSize,
      totalCount: ranked.length,
    );
  }
}
