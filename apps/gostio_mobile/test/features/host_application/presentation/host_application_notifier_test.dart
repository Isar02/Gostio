import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/host_application/presentation/host_application_notifier.dart';

import '../../../support/host_application_double.dart';
import '../../../support/host_application_fixture.dart';

void main() {
  test('the standing is read and says it has been', () async {
    final HostApplicationDouble applications = HostApplicationDouble(
      holds: turnedDown(),
    );
    final HostApplicationNotifier notifier = HostApplicationNotifier(
      applications,
    );

    expect(notifier.hasRead, isFalse);

    await notifier.read();

    expect(notifier.hasRead, isTrue);
    expect(notifier.application?.standing, HostApplicationStatus.rejected);
  });

  // Nothing read and nothing found are different answers, and only one of them
  // is a screen that offers a button.
  test('a refused read is not an account that has never applied', () async {
    final HostApplicationNotifier notifier = HostApplicationNotifier(
      HostApplicationDouble(readFailure: _refused),
    );

    await notifier.read();

    expect(notifier.hasRead, isFalse);
    expect(notifier.application, isNull);
    expect(notifier.readFailureMessage, 'That could not be read.');
  });

  // A pull that was refused leaves what was read standing: it is older rather
  // than wrong, and it is the only thing on the screen that says anything.
  test('a refused refresh leaves the standing that was read', () async {
    final _RefusingSecondRead applications = _RefusingSecondRead(
      hostApplication(),
    );
    final HostApplicationNotifier notifier = HostApplicationNotifier(
      applications,
    );

    await notifier.read();
    await notifier.read();

    expect(notifier.hasRead, isTrue);
    expect(notifier.application?.standing, HostApplicationStatus.pending);
    expect(notifier.readFailureMessage, 'That could not be read.');
  });

  test('applying keeps the row the server answered with', () async {
    final HostApplicationDouble applications = HostApplicationDouble();
    final HostApplicationNotifier notifier = HostApplicationNotifier(
      applications,
    );

    await notifier.read();

    expect(await notifier.apply(), isTrue);
    expect(notifier.application?.standing, HostApplicationStatus.pending);
    expect(applications.applications, 1);
  });

  // The failure this guards is the one that would put an empty standing back
  // over an application the reader has just sent, and then offer to send a
  // second one.
  test('a read that began first cannot undo an application', () async {
    final Completer<void> reads = Completer<void>();
    final HostApplicationDouble applications = HostApplicationDouble(
      holdsReads: reads,
    );
    final HostApplicationNotifier notifier = HostApplicationNotifier(
      applications,
    );

    final Future<void> older = notifier.read();
    await notifier.apply();

    reads.complete();
    await older;

    expect(notifier.application, isNotNull);
  });

  // The refusal belongs to the same overtaken question the answer did. Saying
  // a standing could not be read, over the application the reader has just
  // watched land, describes nothing that is on the screen.
  test('a refusal a read collected on the way is dropped with it', () async {
    final _RefusingHeldRead applications = _RefusingHeldRead();
    final HostApplicationNotifier notifier = HostApplicationNotifier(
      applications,
    );

    final Future<void> older = notifier.read();
    await notifier.apply();

    applications.answer();
    await older;

    expect(notifier.readFailureMessage, isNull);
    expect(notifier.application, isNotNull);
  });

  // Two questions about the same account, where the later answer wins rather
  // than the newer one. Nothing useful is behind a second read.
  test('nothing is read while an application is out', () async {
    final Completer<void> writes = Completer<void>();
    final HostApplicationDouble applications = HostApplicationDouble(
      holdsWrites: writes,
    );
    final HostApplicationNotifier notifier = HostApplicationNotifier(
      applications,
    );

    final Future<bool> sending = notifier.apply();
    await notifier.read();

    expect(applications.reads, isZero);

    writes.complete();
    await sending;
  });

  // A refusal is the server saying the account is not where this screen
  // thought it was. What is drawn under the sentence is read again rather than
  // left as the picture that was just contradicted.
  test('a refused application reads the standing again', () async {
    final _RefusingApplication applications = _RefusingApplication();
    final HostApplicationNotifier notifier = HostApplicationNotifier(
      applications,
    );

    await notifier.read();

    expect(notifier.application, isNull);
    expect(await notifier.apply(), isFalse);
    expect(notifier.refusal, 'A request of yours is already waiting.');
    expect(notifier.application?.standing, HostApplicationStatus.pending);
  });

  test(
    'a refused application supersedes a refresh already in flight',
    () async {
      final _ApplicationDuringRefresh applications =
          _ApplicationDuringRefresh();
      final HostApplicationNotifier notifier = HostApplicationNotifier(
        applications,
      );

      await notifier.read();
      final Future<void> older = notifier.read();

      expect(await notifier.apply(), isFalse);

      applications.answerRefresh();
      await older;

      expect(notifier.refusal, 'A request of yours is already waiting.');
      expect(notifier.application?.standing, HostApplicationStatus.pending);
      expect(applications.reads, 3);
    },
  );
}

const ApiException _refused = ApiException(
  message: 'That could not be read.',
  statusCode: 500,
);

// A read that reaches the server, waits, and is refused there — so a test can
// put an application between its leaving and its refusal.
class _RefusingHeldRead extends HostApplicationDouble {
  final Completer<void> _answer = Completer<void>();

  void answer() => _answer.complete();

  @override
  Future<HostApplication?> mine() async {
    reads++;
    await _answer.future;

    throw _refused;
  }
}

// Answers the first read and refuses every one after it, which is a pull that
// was refused over a standing already on the screen.
class _RefusingSecondRead extends HostApplicationDouble {
  _RefusingSecondRead(this._held);

  final HostApplication _held;

  @override
  Future<HostApplication?> mine() async {
    reads++;

    if (reads > 1) {
      throw _refused;
    }

    return _held;
  }
}

// The refusal a guest meets when an administrator has not answered the
// application they already have: the row exists and this client had not read
// it yet.
class _RefusingApplication extends HostApplicationDouble {
  bool _exists = false;

  @override
  Future<HostApplication?> mine() async {
    reads++;

    return _exists ? hostApplication() : null;
  }

  @override
  Future<HostApplication> apply() async {
    applications++;
    _exists = true;

    throw const ApiException(
      message: 'A request of yours is already waiting.',
      statusCode: 400,
    );
  }
}

class _ApplicationDuringRefresh extends HostApplicationDouble {
  final Completer<void> _refresh = Completer<void>();
  HostApplication _held = turnedDown();

  void answerRefresh() => _refresh.complete();

  @override
  Future<HostApplication?> mine() async {
    reads++;
    final HostApplication answer = _held;

    if (reads == 2) {
      await _refresh.future;
    }

    return answer;
  }

  @override
  Future<HostApplication> apply() async {
    applications++;
    _held = hostApplication();

    throw const ApiException(
      message: 'A request of yours is already waiting.',
      statusCode: 400,
    );
  }
}
