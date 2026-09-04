import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/host_applications_repository.dart';

class HostApplicationDetailNotifier extends ScreenNotifier {
  HostApplicationDetailNotifier(
    this._applications, {
    required this.applicationId,
  });

  final HostApplicationsRepository _applications;

  final int applicationId;

  bool _isLoading = true;
  bool _isWriting = false;
  bool _hasMoved = false;
  HostApplication? _application;
  ApiException? _failure;

  bool get isLoading => _isLoading;

  bool get isWriting => _isWriting;

  bool get isBusy => _isWriting || _isLoading;

  bool get hasMoved => _hasMoved;

  HostApplication? get application => _application;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  Future<void> load() async {
    _isLoading = true;
    publish();

    try {
      _application = await _applications.get(applicationId);
      _failure = null;
    } on ApiException catch (failure) {
      _application = null;
      _failure = failure;
    }

    _isLoading = false;
    publish();
  }

  Future<ApiException?> approve({String? reason}) =>
      _decide(() => _applications.approve(applicationId, reason: reason));

  Future<ApiException?> reject({required String reason}) =>
      _decide(() => _applications.reject(applicationId, reason: reason));

  // Approving grants a role and rejecting sends a notice, and both answer with
  // the request they wrote. That answer is taken: nothing else on this screen
  // moves with the decision, so there is nothing a second read would add.
  Future<ApiException?> _decide(
    Future<HostApplication> Function() write,
  ) async {
    _isWriting = true;
    publish();

    try {
      _application = await write();
      _hasMoved = true;
    } on ApiException catch (refused) {
      _isWriting = false;
      publish();

      return refused;
    }

    _isWriting = false;
    publish();

    return null;
  }
}
