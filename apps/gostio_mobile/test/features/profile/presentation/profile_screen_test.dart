import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/widgets/account_avatar.dart';
import 'package:gostio_mobile/features/profile/data/picture_source.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_details_screen.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_link.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_screen.dart';
import 'package:provider/provider.dart';

import '../../../support/account_fixture.dart';
import '../../../support/auth_double.dart';
import '../../../support/phone.dart';
import '../../../support/picture_double.dart';
import '../../../support/profile_double.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<Session> drawProfile(
    WidgetTester tester, {
    ProfileDouble? profile,
    PictureSourceDouble? pictures,
    User? holds,
    List<ProfileLink> links = const <ProfileLink>[],
    bool settle = true,
  }) async {
    final User signedIn = holds ?? account();
    final Session session = signedOutSession()
      ..begin(account: signedIn, token: 'the-token');

    await tester.pumpWidget(
      underTest(
        _Tab(links: links),
        auth: AuthDouble(),
        session: session,
        // The read as the profile opens answers this account unless a test
        // put another one behind it.
        profile: profile ?? ProfileDouble(holds: signedIn),
        pictures: pictures,
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }

    return session;
  }

  testWidgets('the account is drawn as it is signed in', (
    WidgetTester tester,
  ) async {
    await drawProfile(tester);

    expect(find.text('Emina Begić'), findsOneWidget);
    expect(find.text('emina.b'), findsOneWidget);
    expect(find.text('emina.b@gostio.test'), findsOneWidget);
    expect(find.text('+38761234567'), findsOneWidget);
  });

  testWidgets('an account with no number says so rather than nothing', (
    WidgetTester tester,
  ) async {
    await drawProfile(tester, holds: account(phoneNumber: null));

    expect(find.text('Not given'), findsOneWidget);
  });

  // The account was answered when the token was issued, which on a phone that
  // stays signed in may have been days ago.
  testWidgets('the account is read again as the profile opens', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble(
      holds: account(firstName: 'Amina', lastName: 'Hadžić'),
    );

    final Session session = await drawProfile(tester, profile: profile);

    expect(profile.reads, 1);
    expect(find.text('Amina Hadžić'), findsOneWidget);
    expect(session.account?.fullName, 'Amina Hadžić');
  });

  testWidgets('details wait for the opening account read', (
    WidgetTester tester,
  ) async {
    final Completer<void> heldRead = Completer<void>();
    final ProfileDouble profile = ProfileDouble(
      holds: account(firstName: 'Fresh'),
      holdsReads: heldRead,
    );

    await drawProfile(
      tester,
      profile: profile,
      holds: account(firstName: 'Stale'),
      settle: false,
    );

    await tester.tap(find.text('Your details'));
    await tester.pump();

    expect(find.byType(ProfileDetailsScreen), findsNothing);

    heldRead.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your details'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileDetailsScreen), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Fresh'), findsOneWidget);
  });

  // What is on the screen is the account this session signed in as: older
  // rather than wrong, so it stays and the refusal stands over it.
  testWidgets('a refused read leaves the account that was there standing', (
    WidgetTester tester,
  ) async {
    await drawProfile(
      tester,
      profile: ProfileDouble(
        readFailure: const ApiException(
          message: 'The API could not be reached.',
        ),
      ),
    );

    expect(find.text('The API could not be reached.'), findsOneWidget);
    expect(find.text('Emina Begić'), findsOneWidget);
  });

  testWidgets('an account with no picture is drawn as its initials', (
    WidgetTester tester,
  ) async {
    await drawProfile(tester);

    expect(find.text('EB'), findsOneWidget);
  });

  testWidgets('a picture chosen from the gallery is written and shown', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble();
    final PictureSourceDouble pictures = PictureSourceDouble(
      answer: PictureChosen(picture()),
    );

    await drawProfile(tester, profile: profile, pictures: pictures);

    await tester.tap(find.text('Add a picture'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose from your gallery'));
    await tester.pumpAndSettle();

    expect(pictures.opened, <PictureOrigin>[PictureOrigin.gallery]);
    expect(profile.pictureWritten, isNotNull);
    expect(find.text('Your picture was updated.'), findsOneWidget);
    expect(find.text('EB'), findsNothing);
  });

  // Nothing is undone here, so it is asked about rather than done.
  testWidgets('removing the picture asks before it writes', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble(
      holds: account(hasProfileImage: true),
    );

    await drawProfile(
      tester,
      profile: profile,
      holds: account(hasProfileImage: true),
    );

    await tester.tap(find.text('Change your picture'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove your picture'));
    await tester.pumpAndSettle();

    expect(find.text('Remove your picture?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(profile.wasPictureCleared, isFalse);
  });

  testWidgets('a removal that was agreed to is written', (
    WidgetTester tester,
  ) async {
    final ProfileDouble profile = ProfileDouble(
      holds: account(hasProfileImage: true),
    );

    final Session session = await drawProfile(
      tester,
      profile: profile,
      holds: account(hasProfileImage: true),
    );

    await tester.tap(find.text('Change your picture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove your picture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove picture'));
    await tester.pumpAndSettle();

    expect(profile.wasPictureCleared, isTrue);
    expect(session.account?.hasProfileImage, isFalse);
    expect(find.text('Your picture was removed.'), findsOneWidget);
    expect(find.text('EB'), findsOneWidget);
  });

  // A picture that could not be read is said under the avatar, where the
  // control that asked for it is.
  testWidgets('a gallery that would not open says so on the screen', (
    WidgetTester tester,
  ) async {
    await drawProfile(
      tester,
      pictures: PictureSourceDouble(
        answer: const PictureRefused('The gallery could not be opened.'),
      ),
    );

    await tester.tap(find.text('Add a picture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from your gallery'));
    await tester.pumpAndSettle();

    expect(find.text('The gallery could not be opened.'), findsOneWidget);
  });

  // An account without a picture has nothing to take off it, so the sheet does
  // not offer the one act that would do nothing.
  testWidgets('nothing is offered to remove where there is no picture', (
    WidgetTester tester,
  ) async {
    await drawProfile(tester);

    await tester.tap(find.text('Add a picture'));
    await tester.pumpAndSettle();

    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Remove your picture'), findsNothing);
  });

  testWidgets('the profile leads where its caller says it does', (
    WidgetTester tester,
  ) async {
    bool wasFollowed = false;

    await drawProfile(
      tester,
      links: <ProfileLink>[
        ProfileLink(
          title: 'What you have written',
          message: 'The ratings you left.',
          onTap: () => wasFollowed = true,
        ),
      ],
    );

    await tester.scrollUntilVisible(find.text('What you have written'), 200);
    await tester.tap(find.text('What you have written'));
    await tester.pump();

    expect(wasFollowed, isTrue);
  });

  testWidgets('the picture is drawn from the account it belongs to', (
    WidgetTester tester,
  ) async {
    await drawProfile(tester, holds: account(hasProfileImage: true));

    expect(
      tester
          .widgetList<AccountAvatar>(find.byType(AccountAvatar))
          .single
          .hasImage,
      isTrue,
    );
  });
}

// The profile is drawn under a bar and over the session, the way the shell
// composes it: what a write puts back is read from there, so the screen has to
// be rebuilt from there too.
class _Tab extends StatelessWidget {
  const _Tab({required this.links});

  final List<ProfileLink> links;

  @override
  Widget build(BuildContext context) {
    final User? account = context.select<Session, User?>(
      (Session session) => session.account,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: account == null
          ? const SizedBox.shrink()
          : ProfileScreen(account: account, onSignOut: () {}, links: links),
    );
  }
}
