import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/widgets/account_avatar.dart';
import 'package:gostio_mobile/core/widgets/api_image.dart';

import '../../support/phone.dart';
import '../../support/widgets.dart';

void main() {
  setUp(usePhoneScreen);

  // Two letters tell a reader which of two names this is. A silhouette of a
  // head every account shares tells them nothing.
  testWidgets('an account with no picture is drawn as its initials', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(const AccountAvatar(userId: 12, name: 'Emina Begić')),
    );

    expect(find.text('EB'), findsOneWidget);
    expect(find.byType(ApiImage), findsNothing);
  });

  testWidgets('a single name is one letter rather than none', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(const AccountAvatar(userId: 12, name: 'Emina')),
    );

    expect(find.text('E'), findsOneWidget);
  });

  // A name with more than two words is still two letters: three initials in a
  // circle this size stop being readable.
  testWidgets('a longer name is read down to the first two', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(const AccountAvatar(userId: 12, name: 'Emina Sara Begić')),
    );

    expect(find.text('ES'), findsOneWidget);
  });

  testWidgets('a picture is fetched from the account it belongs to', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        const AccountAvatar(userId: 12, name: 'Emina Begić', hasImage: true),
      ),
    );
    // The picture is a request of its own, and this lets the one it made
    // finish rather than leaving it out at the end of the test.
    await tester.pumpAndSettle();

    expect(
      tester.widget<ApiImage>(find.byType(ApiImage)).path,
      '/users/12/image',
    );
    expect(find.text('EB'), findsNothing);
  });
}
