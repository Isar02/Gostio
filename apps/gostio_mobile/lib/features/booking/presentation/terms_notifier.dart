import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/booking_repository.dart';

// The terms one experience still has open, and the ones the reader is already
// on. The experience is the whole query, so the paging carries nothing of its
// own.
class TermsNotifier extends PagedNotifier<ExperienceSlot, void> {
  TermsNotifier(this._repository, this._experienceId) : super(null) {
    unawaited(reload());
  }

  final BookingRepository _repository;
  final int _experienceId;

  Set<int> _alreadyHeld = const <int>{};

  Set<int> get alreadyHeld => _alreadyHeld;

  @override
  @protected
  Future<PagedResult<ExperienceSlot>> fetch({
    required int page,
    required void query,
  }) async {
    // Read before the terms rather than beside them: a list that cannot say
    // which terms the reader is already on would offer a second booking on one
    // of them, and a refusal after the press is what this screen exists to
    // avoid. Later pages keep the answer the first one landed with.
    if (page == 1) {
      _alreadyHeld = await _repository.termsAlreadyHeld(_experienceId);
    }

    return _repository.terms(_experienceId, page: page, pageSize: pageSize);
  }
}
