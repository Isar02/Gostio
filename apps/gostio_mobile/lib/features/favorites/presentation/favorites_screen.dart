import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/paged_list.dart';
import '../../listing/presentation/favorite_edits.dart';
import '../data/favorites_repository.dart';
import 'favorite_card.dart';
import 'favorites_notifier.dart';

// What this account has kept, reached from the profile. Stays and terms are
// one list rather than two behind a toggle: they are saved by one gesture into
// one place, and the order they were saved in is the order they are looked for
// in.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const FavoritesScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FavoritesNotifier>(
      create: (BuildContext context) => FavoritesNotifier(
        context.read<FavoritesRepository>(),
        context.read<FavoriteEdits>(),
      ),
      child: const _Favorites(),
    );
  }
}

class _Favorites extends StatelessWidget {
  const _Favorites();

  @override
  Widget build(BuildContext context) {
    final FavoritesNotifier saved = context.watch<FavoritesNotifier>();

    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: SafeArea(
        child: PagedList<Favorite>(
          items: saved.items,
          totalCount: saved.totalCount,
          noun: 'saved',
          isLoading: saved.isLoading,
          isAppending: saved.isAppending,
          failureMessage: saved.failureMessage,
          failureTraceId: saved.failureTraceId,
          onMore: saved.more,
          onRetry: saved.retry,
          onRefresh: saved.reload,
          emptyTitle: 'You have not saved anything yet',
          emptyMessage:
              'The heart on a stay or an experience keeps it here, and the '
              'same heart takes it back off.',
          itemBuilder: (BuildContext context, Favorite one) =>
              FavoriteCard(one),
        ),
      ),
    );
  }
}
