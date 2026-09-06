import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/favorites/data/favorites_repository.dart';

// What an account has kept, answered without a socket. Every page asked for is
// recorded, so a test says whether a change came back to the list or sent the
// list back to the server for it.
class FavoritesDouble implements FavoritesRepository {
  FavoritesDouble({this.kept = const <Favorite>[], this.failure});

  final List<Favorite> kept;
  final ApiException? failure;

  final List<int> pagesAsked = <int>[];

  @override
  Future<PagedResult<Favorite>> saved({
    required int page,
    required int pageSize,
  }) async {
    pagesAsked.add(page);

    if (failure case final ApiException refused) {
      throw refused;
    }

    final int from = ((page - 1) * pageSize).clamp(0, kept.length);
    final int to = (from + pageSize).clamp(0, kept.length);

    return PagedResult<Favorite>(
      items: kept.sublist(from, to),
      page: page,
      pageSize: pageSize,
      totalCount: kept.length,
    );
  }
}
