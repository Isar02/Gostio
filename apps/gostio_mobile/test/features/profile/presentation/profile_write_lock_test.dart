import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_write_lock.dart';

void main() {
  late ProfileWriteLock lock;

  setUp(() => lock = ProfileWriteLock());

  tearDown(() => lock.dispose());

  test(
    'a write is out while it is held and finished when it answers',
    () async {
      final Completer<bool> answer = Completer<bool>();
      final Future<bool> writing = lock.holding(() => answer.future);

      expect(lock.isWriting, isTrue);

      answer.complete(true);

      expect(await writing, isTrue);
      expect(lock.isWriting, isFalse);
    },
  );

  // The one thing this exists for. A password that lands while a details save
  // is in flight raises the account's token version, and the save already on
  // its way is answered with a 401 that would end the session.
  test('a second write while one is out never runs', () async {
    final Completer<bool> answer = Completer<bool>();
    final Future<bool> first = lock.holding(() => answer.future);

    bool secondRan = false;
    final bool second = await lock.holding(() async {
      secondRan = true;

      return true;
    });

    expect(secondRan, isFalse);
    expect(second, isFalse);

    answer.complete(true);
    await first;
  });

  test('a write that was refused releases the lock behind it', () async {
    await lock.holding(() async => false);

    expect(lock.isWriting, isFalse);

    bool ran = false;
    await lock.holding(() async {
      ran = true;

      return true;
    });

    expect(ran, isTrue);
  });

  // A repository that threw rather than answered is still a write that is over.
  // Left held, the account could never be written again in this session.
  test('a write that threw releases the lock behind it', () async {
    await expectLater(
      lock.holding(() async => throw StateError('the call fell over')),
      throwsStateError,
    );

    expect(lock.isWriting, isFalse);
  });

  // A read of the account is only worth applying while no write has begun since
  // it left, and this figure is what a read compares itself against.
  test('every write that began is counted, and a refused one is not', () async {
    expect(lock.writes, 0);

    await lock.holding(() async => true);
    await lock.holding(() async => false);

    expect(lock.writes, 2);

    final Completer<bool> answer = Completer<bool>();
    final Future<bool> first = lock.holding(() => answer.future);
    await lock.holding(() async => true);

    // The second never ran, so nothing about the account changed with it.
    expect(lock.writes, 3);

    answer.complete(true);
    await first;
  });

  test('what is holding is announced to whoever is drawing it', () async {
    int announcements = 0;
    lock.addListener(() => announcements++);

    await lock.holding(() async => true);

    expect(announcements, 2);
  });
}
