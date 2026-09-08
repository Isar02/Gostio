import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/core/theme/app_theme.dart';
import 'package:gostio_desktop/features/notifications/presentation/notifications_notifier.dart';
import 'package:gostio_desktop/features/notifications/presentation/notifications_panel.dart';
import 'package:provider/provider.dart';

import '../../../support/notifications_double.dart';

void main() {
  // The real faces, so the panel is measured at the widths it really has. A
  // widget test fails on an overflow, so drawing it is the check.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    for (final String family in <String>[
      'Geist',
      'PlusJakartaSans',
      'Manrope',
    ]) {
      await _load(family);
    }
  });

  // Both ends of the panel's lifetime have to land. Reading the provider back
  // out of `dispose` does not: the element has left the tree by then.
  testWidgets('a panel that closes tells the list it is no longer up', (
    WidgetTester tester,
  ) async {
    final NotificationsNotifier notifications = _aList();

    await tester.pumpWidget(
      _holding(notifications, const NotificationsPanel()),
    );
    await tester.pumpAndSettle();

    expect(notifications.isOnScreen, isTrue);

    await tester.pumpWidget(_holding(notifications, const Text('closed')));
    await tester.pumpAndSettle();

    expect(notifications.isOnScreen, isFalse);

    notifications.dispose();
  });

  // One end that does not land leaves the count above zero for good.
  testWidgets('a panel opened again is still let go of', (
    WidgetTester tester,
  ) async {
    final NotificationsNotifier notifications = _aList();

    for (int opened = 0; opened < 2; opened++) {
      await tester.pumpWidget(
        _holding(notifications, const NotificationsPanel()),
      );
      await tester.pumpAndSettle();

      expect(notifications.isOnScreen, isTrue);

      await tester.pumpWidget(_holding(notifications, const Text('closed')));
      await tester.pumpAndSettle();

      expect(notifications.isOnScreen, isFalse);
    }

    notifications.dispose();
  });
}

// Given up inside the body: a widget test wants no timer standing by the time
// a tear-down runs.
NotificationsNotifier _aList() =>
    NotificationsNotifier(NotificationsDouble(<AppNotification>[]));

// The client's own theme, or the header measured is not the one that ships.
Widget _holding(NotificationsNotifier notifications, Widget child) =>
    ChangeNotifierProvider<NotificationsNotifier>.value(
      value: notifications,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Future<void> _load(String family) async {
  final FontLoader faces = FontLoader(family);

  for (final String file in _files[family]!) {
    faces.addFont(rootBundle.load('packages/gostio_core/assets/fonts/$file'));
  }

  await faces.load();
}

const Map<String, List<String>> _files = <String, List<String>>{
  'Geist': <String>[
    'Geist-Regular.ttf',
    'Geist-Medium.ttf',
    'Geist-SemiBold.ttf',
  ],
  'PlusJakartaSans': <String>[
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
  ],
  'Manrope': <String>['Manrope-Regular.ttf', 'Manrope-SemiBold.ttf'],
};
