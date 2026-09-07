import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/profile/data/picture_source.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_notifier.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_write_lock.dart';

import '../../../support/account_fixture.dart';
import '../../../support/picture_double.dart';
import '../../../support/profile_double.dart';
import '../../../support/screens.dart';

void main() {
  // A session that ends empties the picture cache, which is the framework's
  // rather than this client's.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Session session;
  late ProfileWriteLock lock;

  setUp(() {
    session = signedOutSession()..begin(account: account(), token: 'the-token');
    lock = ProfileWriteLock();
  });

  tearDown(() {
    session.dispose();
    lock.dispose();
  });

  ProfileNotifier notifierOver(
    ProfileDouble profile, {
    PictureSource? pictures,
  }) => ProfileNotifier(
    profile,
    pictures ?? PictureSourceDouble(),
    session,
    lock,
  );

  // The account this session holds was answered when the token was issued,
  // which on a phone that stays signed in may have been days ago.
  test('a read replaces the account the rest of the client draws', () async {
    final ProfileDouble profile = ProfileDouble(
      holds: account(firstName: 'Amina', lastName: 'Hadžić'),
    );
    final ProfileNotifier notifier = notifierOver(profile);

    await notifier.refresh();

    expect(profile.reads, 1);
    expect(session.account?.fullName, 'Amina Hadžić');
    expect(notifier.refreshFailureMessage, isNull);

    notifier.dispose();
  });

  // What is on the screen is the account this session signed in as. It is
  // older rather than wrong, so a refused read says so and leaves it standing.
  test('a refused read says so and keeps the account that was there', () async {
    final ProfileNotifier notifier = notifierOver(
      ProfileDouble(
        readFailure: const ApiException(
          message: 'The API could not be reached.',
        ),
      ),
    );

    await notifier.refresh();

    expect(notifier.refreshFailureMessage, 'The API could not be reached.');
    expect(session.account?.fullName, 'Emina Begić');

    notifier.dispose();
  });

  test('a picture chosen from the gallery is written and taken up', () async {
    final ProfileDouble profile = ProfileDouble();
    final PictureSourceDouble pictures = PictureSourceDouble(
      answer: PictureChosen(picture()),
    );
    final ProfileNotifier notifier = notifierOver(profile, pictures: pictures);

    expect(await notifier.choosePicture(PictureOrigin.gallery), isTrue);

    expect(pictures.opened, <PictureOrigin>[PictureOrigin.gallery]);
    expect(profile.pictureWritten?.name, 'face.png');
    expect(session.account?.hasProfileImage, isTrue);
    expect(notifier.pictureMessage, isNull);

    notifier.dispose();
  });

  // The bytes are read either way, so this client mirrors the rule the server
  // would answer with rather than spending the request to be told it.
  test('bytes of no kind the server takes are never sent', () async {
    final ProfileDouble profile = ProfileDouble();
    final ProfileNotifier notifier = notifierOver(
      profile,
      pictures: PictureSourceDouble(answer: PictureChosen(notAPicture())),
    );

    expect(await notifier.choosePicture(PictureOrigin.gallery), isFalse);

    expect(profile.pictureWritten, isNull);
    expect(notifier.pictureMessage, contains('image/jpeg'));

    notifier.dispose();
  });

  test('a reader who backed out of the camera is told nothing', () async {
    final ProfileDouble profile = ProfileDouble();
    final ProfileNotifier notifier = notifierOver(profile);

    expect(await notifier.choosePicture(PictureOrigin.camera), isFalse);

    expect(profile.pictureWritten, isNull);
    expect(notifier.pictureMessage, isNull);

    notifier.dispose();
  });

  test('a camera that would not open says which door it was', () async {
    final ProfileNotifier notifier = notifierOver(
      ProfileDouble(),
      pictures: PictureSourceDouble(
        answer: const PictureRefused('The camera could not be opened.'),
      ),
    );

    expect(await notifier.choosePicture(PictureOrigin.camera), isFalse);
    expect(notifier.pictureMessage, 'The camera could not be opened.');

    notifier.dispose();
  });

  test('the picture is removed and the account says so', () async {
    final ProfileDouble profile = ProfileDouble(
      holds: account(hasProfileImage: true),
    );
    final ProfileNotifier notifier = notifierOver(profile);

    expect(await notifier.removePicture(), isTrue);

    expect(profile.wasPictureCleared, isTrue);
    expect(session.account?.hasProfileImage, isFalse);

    notifier.dispose();
  });

  // The file has no field of its own on the screen to fault, so what the
  // server said about the file is preferred over the summary above it.
  test('a refused write says what the server said about the file', () async {
    final ProfileNotifier notifier = notifierOver(
      ProfileDouble(
        pictureFailure: const ApiException(
          message: 'The request was not valid.',
          errors: <String, List<String>>{
            'File': <String>['An image is at most 4 MB.'],
          },
        ),
      ),
      pictures: PictureSourceDouble(answer: PictureChosen(picture())),
    );

    expect(await notifier.choosePicture(PictureOrigin.gallery), isFalse);
    expect(notifier.pictureMessage, 'An image is at most 4 MB.');

    notifier.dispose();
  });

  // Choosing again is a new answer to the same question, so what was said
  // about the last one goes with it.
  test('choosing again clears what the last refusal said', () async {
    final PictureSourceDouble pictures = PictureSourceDouble(
      answer: PictureChosen(notAPicture()),
    );
    final ProfileNotifier notifier = notifierOver(
      ProfileDouble(),
      pictures: pictures,
    );

    await notifier.choosePicture(PictureOrigin.gallery);
    expect(notifier.pictureMessage, isNotNull);

    pictures.answer = PictureChosen(picture());

    expect(await notifier.choosePicture(PictureOrigin.gallery), isTrue);
    expect(notifier.pictureMessage, isNull);

    notifier.dispose();
  });

  test('a picture write while another write is out never runs', () async {
    final Completer<void> held = Completer<void>();
    final ProfileDouble profile = ProfileDouble(holdsWrites: held);
    final ProfileNotifier notifier = notifierOver(
      profile,
      pictures: PictureSourceDouble(answer: PictureChosen(picture())),
    );

    final Future<bool> first = notifier.choosePicture(PictureOrigin.gallery);
    await pumpEventQueue();

    expect(lock.isWriting, isTrue);
    expect(await notifier.removePicture(), isFalse);
    expect(profile.wasPictureCleared, isFalse);

    held.complete();
    expect(await first, isTrue);

    notifier.dispose();
  });

  // A read is only worth applying while it is still the newest thing said about
  // this account. A picture or a details write that began after the read left
  // has already answered a fresher account, and the read overtaking it would
  // put back what the reader has just changed.
  test('a read that a write overtook is dropped rather than applied', () async {
    final ProfileDouble profile = ProfileDouble(
      holds: account(firstName: 'Stale'),
    );
    final ProfileNotifier notifier = notifierOver(profile);

    final Future<void> reading = notifier.refresh();

    // The write begins while the read is still out, and answers first.
    await lock.holding(() async {
      session.accountChanged(account(firstName: 'Fresh'));

      return true;
    });

    await reading;

    expect(session.account?.firstName, 'Fresh');

    notifier.dispose();
  });

  test('a read is not begun while an older write is still out', () async {
    final Completer<void> heldRead = Completer<void>();
    final Completer<void> heldWrite = Completer<void>();
    final ProfileDouble profile = ProfileDouble(
      holds: account(firstName: 'Stale'),
      holdsReads: heldRead,
    );
    final ProfileNotifier notifier = notifierOver(profile);

    final Future<bool> writing = lock.holding(() async {
      await heldWrite.future;
      session.accountChanged(account(firstName: 'Fresh'));

      return true;
    });
    final Future<void> reading = notifier.refresh();
    await pumpEventQueue();

    heldWrite.complete();
    await writing;
    heldRead.complete();
    await reading;

    expect(profile.reads, 0);
    expect(session.account?.firstName, 'Fresh');

    notifier.dispose();
  });

  // The same read landing in a session that has become somebody else's would
  // draw one reader's account under the other reader's name.
  test('a read that lands in another reader session is dropped', () async {
    final ProfileNotifier notifier = notifierOver(
      ProfileDouble(holds: account(firstName: 'Emina')),
    );

    final Future<void> reading = notifier.refresh();

    session
      ..end(SessionEnding.signedOut)
      ..begin(
        account: account(id: 33, firstName: 'Lejla', username: 'other'),
        token: 'b-token',
      );

    await reading;

    expect(session.account?.id, 33);
    expect(session.account?.firstName, 'Lejla');

    notifier.dispose();
  });

  test(
    'a picture write that lands in another reader session is dropped',
    () async {
      final Completer<void> held = Completer<void>();
      final ProfileNotifier notifier = notifierOver(
        ProfileDouble(holdsWrites: held, holds: account(hasProfileImage: true)),
        pictures: PictureSourceDouble(answer: PictureChosen(picture())),
      );

      final Future<bool> writing = notifier.choosePicture(
        PictureOrigin.gallery,
      );
      await pumpEventQueue();

      session
        ..end(SessionEnding.signedOut)
        ..begin(
          account: account(id: 33, username: 'other'),
          token: 'b-token',
        );

      held.complete();
      await writing;

      expect(session.account?.id, 33);
      expect(session.account?.hasProfileImage, isFalse);

      notifier.dispose();
    },
  );

  // A reader lining up a photograph is not a request in flight, and holding
  // the lock across the camera would leave the account unwritable for as long
  // as they took over it.
  test('choosing is outside the lock and only the write is inside', () async {
    final ProfileNotifier notifier = notifierOver(
      ProfileDouble(),
      pictures: _WatchingPictures(lock),
    );

    await notifier.choosePicture(PictureOrigin.camera);

    expect(notifier.pictureMessage, isNull);

    notifier.dispose();
  });
}

// Reads the lock at the moment the camera would be open, and refuses if
// anything was holding it then.
class _WatchingPictures implements PictureSource {
  _WatchingPictures(this._lock);

  final ProfileWriteLock _lock;

  @override
  Future<PictureChoice> pick(PictureOrigin origin) async => _lock.isWriting
      ? const PictureRefused('The lock was held while the camera was open.')
      : PictureChosen(picture());
}
