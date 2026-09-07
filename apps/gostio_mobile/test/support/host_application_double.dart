import 'dart:async';

import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/host_application/data/host_application_repository.dart';

import 'host_application_fixture.dart';

// Where an account stands on hosting, answered without a server. Both calls
// count and both may be held open, which is how a test says what a read landing
// after an application does with what it is holding.
class HostApplicationDouble implements HostApplicationRepository {
  HostApplicationDouble({
    HostApplication? holds,
    this.made,
    this.readFailure,
    this.applyFailure,
    this.holdsReads,
    this.holdsWrites,
  }) : _held = holds;

  // What applying answers with, where a test cares. Otherwise it is the row
  // the server would write: this account, waiting.
  final HostApplication? made;

  final ApiException? readFailure;
  final ApiException? applyFailure;

  // A read waits here after taking its answer, so a test can order it against
  // an application that began before or after it.
  final Completer<void>? holdsReads;
  final Completer<void>? holdsWrites;

  int reads = 0;
  int applications = 0;

  HostApplication? _held;

  @override
  Future<HostApplication?> mine() async {
    reads++;
    final HostApplication? read = _held;

    if (readFailure case final ApiException refused) {
      throw refused;
    }

    await holdsReads?.future;

    return read;
  }

  @override
  Future<HostApplication> apply() async {
    applications++;
    await holdsWrites?.future;

    if (applyFailure case final ApiException refused) {
      throw refused;
    }

    return _held = made ?? hostApplication();
  }
}
