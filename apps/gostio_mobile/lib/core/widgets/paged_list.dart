import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';
import 'app_notice.dart';
import 'screen_states.dart';

// A server-paged list read with a thumb. Pages are added rather than swapped,
// and the count says how much of the whole is being held, because a list that
// grows under the reader with no figure beside it never says where it ends.
//
// The next page is asked for rather than taken: an endless list that fetches
// itself cannot be stopped, and each page here is a request the reader made.
class PagedList<T> extends StatelessWidget {
  const PagedList({
    required this.items,
    required this.totalCount,
    required this.itemBuilder,
    required this.onMore,
    this.isLoading = false,
    this.isAppending = false,
    this.failureMessage,
    this.failureTraceId,
    this.onRetry,
    this.onRefresh,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyAction,
    this.header,
    this.noun = 'items',
    super.key,
  });

  final List<T> items;
  final int totalCount;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onMore;
  final bool isLoading;
  final bool isAppending;
  final String? failureMessage;
  final String? failureTraceId;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;
  final String emptyTitle;
  final String? emptyMessage;
  final Widget? emptyAction;
  final Widget? header;
  final String noun;

  bool get _hasMore => items.length < totalCount;

  @override
  Widget build(BuildContext context) {
    // Nothing has been read yet, so there is nothing to keep on the screen
    // while the answer is waited for. A list with nothing in it is still a
    // list, so the gesture that reads it again is still under the thumb: an
    // empty answer is the one a reader most wants to pull on.
    if (items.isEmpty) {
      if (isLoading) {
        return _pullable(const LoadingState());
      }

      if (failureMessage case final String message) {
        return _pullable(
          ErrorState(
            message: message,
            traceId: failureTraceId,
            onRetry: onRetry,
          ),
        );
      }

      return _pullable(
        EmptyState(
          title: emptyTitle,
          message: emptyMessage,
          icon: Icons.search_off_rounded,
          action: emptyAction,
        ),
      );
    }

    final Widget list = ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      // The header scrolls with the list, and the footer is the last row
      // rather than a bar pinned over the final card.
      itemCount: items.length + (header == null ? 1 : 2),
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        final int offset = header == null ? 0 : 1;

        if (header case final Widget header when index == 0) {
          return header;
        }

        if (index - offset < items.length) {
          return itemBuilder(context, items[index - offset]);
        }

        return _Footer(
          loaded: items.length,
          totalCount: totalCount,
          noun: noun,
          hasMore: _hasMore,
          isAppending: isAppending,
          failureMessage: failureMessage,
          onMore: onMore,
          onRetry: onRetry,
        );
      },
    );

    return _refreshing(list) ?? list;
  }

  // A screen state fills what it was given and scrolls nowhere, and a pull
  // needs something that can be overscrolled. It is laid inside a list as tall
  // as the space it was handed, so it reads exactly as it did and answers the
  // gesture as the rows would.
  Widget _pullable(Widget state) =>
      _refreshing(
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints space) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: space.maxHeight),
                child: state,
              ),
            ],
          ),
        ),
      ) ??
      state;

  Widget? _refreshing(Widget child) => onRefresh == null
      ? null
      : RefreshIndicator(
          onRefresh: onRefresh!,
          color: AppColors.indigo,
          child: child,
        );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.loaded,
    required this.totalCount,
    required this.noun,
    required this.hasMore,
    required this.isAppending,
    required this.onMore,
    this.onRetry,
    this.failureMessage,
  });

  final int loaded;
  final int totalCount;
  final String noun;
  final bool hasMore;
  final bool isAppending;
  final VoidCallback onMore;
  final VoidCallback? onRetry;
  final String? failureMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
      child: Column(
        children: <Widget>[
          Text(
            '$loaded of $totalCount $noun',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkMuted),
          ),
          // A page that failed to arrive leaves what was already read alone
          // and says so under it, where the button that asked for it is.
          if (failureMessage case final String message) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(message),
          ],
          if (isAppending) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            const SizedBox(
              width: AppSizes.spinner,
              height: AppSizes.spinner,
              child: CircularProgressIndicator(strokeWidth: AppSizes.stroke),
            ),
          ]
          // Another go retries the read that was refused; only a list that
          // landed whole is offered more. The two are never the same button,
          // and a failure is worth answering whether or not a page is left.
          else if (failureMessage != null) ...<Widget>[
            if (onRetry case final VoidCallback onRetry) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ] else if (hasMore) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onMore, child: const Text('Show more')),
          ],
        ],
      ),
    );
  }
}
