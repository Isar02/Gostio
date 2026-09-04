import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/overview_repository.dart';
import '../data/platform_overview.dart';

// The administrator's panel is one read: nothing on it is filtered and nothing
// on it moves on its own, so there is one request in flight at a time and one
// thing to say about it.
class PlatformOverviewNotifier extends ScreenNotifier {
  PlatformOverviewNotifier(this._overview);

  final OverviewRepository _overview;

  int _request = 0;
  bool _isLoading = false;
  PlatformOverview? _standing;
  ApiException? _failure;

  bool get isLoading => _isLoading;

  PlatformOverview? get standing => _standing;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  Future<void> reload() async {
    final int request = ++_request;

    _isLoading = true;
    _failure = null;
    publish();

    PlatformOverview? standing;
    ApiException? failure;

    try {
      standing = await _overview.platform();
    } on ApiException catch (thrown) {
      failure = thrown;
    }

    if (request != _request) {
      return;
    }

    _standing = standing;
    _failure = failure;
    _isLoading = false;
    publish();
  }
}
