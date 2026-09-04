import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/news_draft.dart';
import '../data/news_repository.dart';

// A save with nothing to write is not a write.
enum NewsWrite { written, unchanged, refused }

class NewsDetailNotifier extends ScreenNotifier {
  NewsDetailNotifier(this._news, {required this.newsId});

  final NewsRepository _news;

  // Absent means the screen is writing an article rather than editing one.
  final int? newsId;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanged = false;
  NewsItem? _item;
  ApiException? _failure;
  ApiException? _writeFailure;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get isWriting => newsId == null;

  bool get hasChanged => _hasChanged;

  NewsItem? get item => _item;

  // A load that failed empties the screen; a write that failed is said above
  // the form.
  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  String? get writeFailureMessage => _writeFailure?.message;

  String? messageFor(String field) => _writeFailure?.firstMessageFor(field);

  Future<void> load() async {
    final int? id = newsId;

    _isLoading = true;
    _failure = null;
    _writeFailure = null;
    publish();

    if (id != null) {
      try {
        _item = await _news.get(id);
      } on ApiException catch (failure) {
        _failure = failure;
      }
    }

    _isLoading = false;
    publish();
  }

  Future<NewsWrite> publishArticle(NewsDraft draft, ImageUpload image) =>
      _write(() => _news.create(draft, image));

  // The endpoint stamps the article as edited for anything it is given.
  Future<NewsWrite> saveChanges(NewsDraft draft, {ImageUpload? image}) {
    final int? id = newsId;
    final NewsItem? current = _item;
    if (id == null || current == null) {
      return Future<NewsWrite>.value(NewsWrite.refused);
    }

    if (image == null && draft.hasSameTextAs(current)) {
      // The refusal was about what stood in the form then.
      _writeFailure = null;
      publish();

      return Future<NewsWrite>.value(NewsWrite.unchanged);
    }

    return _write(() => _news.update(id, draft, image: image));
  }

  Future<bool> delete() async {
    final int? id = newsId;
    if (id == null) {
      return false;
    }

    _isSaving = true;
    _writeFailure = null;
    publish();

    try {
      await _news.delete(id);

      return true;
    } on ApiException catch (failure) {
      _writeFailure = failure;
      _isSaving = false;
      publish();

      return false;
    }
  }

  Future<NewsWrite> _write(Future<NewsItem> Function() write) async {
    _isSaving = true;
    _writeFailure = null;
    publish();

    NewsWrite outcome = NewsWrite.refused;

    try {
      _item = await write();
      _hasChanged = true;
      outcome = NewsWrite.written;
    } on ApiException catch (failure) {
      _writeFailure = failure;
    }

    _isSaving = false;
    publish();

    return outcome;
  }
}
