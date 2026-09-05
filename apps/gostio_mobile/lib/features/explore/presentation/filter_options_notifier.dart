import 'dart:async';

import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/live_notifier.dart';
import '../data/filter_options.dart';
import '../data/filter_options_repository.dart';

// The choices both sheets are built from, read once and kept. A refusal is
// held rather than raised over the results: the catalogue is still searchable
// by what was typed, and only the sheet is the poorer for it.
class FilterOptionsNotifier extends LiveNotifier {
  FilterOptionsNotifier(this._repository) {
    unawaited(load());
  }

  final FilterOptionsRepository _repository;

  bool _isLoading = false;
  FilterOptions _options = FilterOptions.none;
  ApiException? _failure;

  bool get isLoading => _isLoading;

  FilterOptions get options => _options;

  String? get failureMessage => _failure?.message;

  Future<void> load() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _failure = null;
    publish();

    try {
      _options = await _repository.read();
    } on ApiException catch (refused) {
      _failure = refused;
    }

    _isLoading = false;
    publish();
  }
}
