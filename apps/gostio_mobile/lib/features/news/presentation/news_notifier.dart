import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/news_repository.dart';

// What has been published, newest first, as the server orders it. It has no
// filter of its own, so the query it pages under carries nothing.
class NewsNotifier extends PagedNotifier<NewsItem, void> {
  NewsNotifier(this._repository) : super(null) {
    unawaited(reload());
  }

  final NewsRepository _repository;

  @override
  @protected
  Future<PagedResult<NewsItem>> fetch({
    required int page,
    required void query,
  }) => _repository.search(page: page, pageSize: pageSize);
}
