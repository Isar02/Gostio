import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/theme/app_theme.dart';
import 'package:gostio_mobile/features/auth/data/auth_repository.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

Session signedOutSession() =>
    Session(ApiClient(baseUrl: Uri.parse('http://10.0.2.2:5000')));

// One screen under the providers the client composes above it, drawn in the
// theme it is actually read in.
Widget underTest(
  Widget screen, {
  required AuthRepository auth,
  Session? session,
  GlobalKey<NavigatorState>? navigator,
}) => MultiProvider(
  providers: <SingleChildWidget>[
    ChangeNotifierProvider<Session>.value(value: session ?? signedOutSession()),
    Provider<AuthRepository>.value(value: auth),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    navigatorKey: navigator,
    home: screen,
  ),
);

// A screen the client only ever reaches by pushing it is drawn over something
// here too, so the arrow in its bar and the gesture behind it both exist.
Future<void> pushOnto(
  WidgetTester tester,
  Widget screen, {
  required AuthRepository auth,
  Session? session,
}) async {
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();

  await tester.pumpWidget(
    underTest(
      const Scaffold(),
      auth: auth,
      session: session,
      navigator: navigator,
    ),
  );

  unawaited(
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (BuildContext context) => screen),
    ),
  );

  await tester.pumpAndSettle();
}
