import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/app/shell/app_section.dart';
import 'package:gostio_desktop/app/shell/shell_navigation.dart';
import 'package:gostio_desktop/app/shell/workspace.dart';
import 'package:gostio_desktop/app/shell/workspace_mode.dart';
import 'package:gostio_desktop/features/messages/presentation/chat_unread_notifier.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/conversation_doubles.dart';

void main() {
  // The tap used to take the group out and the section put it straight back.
  testWidgets('a group holding the open section still closes on its header', (
    WidgetTester tester,
  ) async {
    final Workspace workspace = Workspace(<WorkspaceMode>[
      WorkspaceMode.administrator,
    ]);
    addTearDown(workspace.dispose);

    await tester.pumpWidget(_navigation(workspace));
    await tester.pumpAndSettle();

    expect(find.text('Countries'), findsNothing);

    await tester.tap(find.text('Reference data'));
    await tester.pumpAndSettle();

    expect(find.text('Countries'), findsOneWidget);

    await tester.tap(find.text('Countries'));
    await tester.pumpAndSettle();

    expect(workspace.section, AppSection.countries);
    expect(find.text('Countries'), findsOneWidget);

    await tester.tap(find.text('Reference data'));
    await tester.pumpAndSettle();

    expect(find.text('Countries'), findsNothing);
  });

  // And it opens again on the next tap.
  testWidgets('a group closed by hand opens again on the same header', (
    WidgetTester tester,
  ) async {
    final Workspace workspace = Workspace(<WorkspaceMode>[
      WorkspaceMode.administrator,
    ]);
    addTearDown(workspace.dispose);

    await tester.pumpWidget(_navigation(workspace));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reference data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cities'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reference data'));
    await tester.pumpAndSettle();

    expect(find.text('Cities'), findsNothing);

    await tester.tap(find.text('Reference data'));
    await tester.pumpAndSettle();

    expect(find.text('Cities'), findsOneWidget);
    expect(workspace.section, AppSection.cities);
  });

  // A group nobody has spoken about follows the section.
  testWidgets('a group is open when the section arrives inside it', (
    WidgetTester tester,
  ) async {
    final Workspace workspace = Workspace(<WorkspaceMode>[
      WorkspaceMode.administrator,
    ])..open(AppSection.amenities);
    addTearDown(workspace.dispose);

    await tester.pumpWidget(_navigation(workspace));
    await tester.pumpAndSettle();

    expect(find.text('Amenities'), findsOneWidget);
  });
}

Widget _navigation(Workspace workspace) => MultiProvider(
  providers: <SingleChildWidget>[
    ChangeNotifierProvider<Workspace>.value(value: workspace),
    ChangeNotifierProvider<ChatUnreadNotifier>(
      create: (BuildContext context) => ChatUnreadNotifier(MessagesDouble()),
    ),
  ],
  child: const MaterialApp(home: Scaffold(body: ShellNavigation())),
);
