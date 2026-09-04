import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/widgets/password_field.dart';

import '../../support/phone.dart';

void main() {
  setUp(usePhoneScreen);

  testWidgets('a password is hidden until the reveal is asked for', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _TwoPasswords());

    expect(_isHidden(tester, 'First'), isTrue);

    await tester.tap(find.byTooltip('Show the password').first);
    await tester.pumpAndSettle();

    expect(_isHidden(tester, 'First'), isFalse);
  });

  // The reveal sits inside the field, and Next on the keyboard means the field
  // after this one rather than the button in it.
  testWidgets('the reveal is not what Next reaches', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _TwoPasswords());

    await tester.tap(find.widgetWithText(TextFormField, 'First'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.widgetWithText(TextFormField, 'Second'),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
  });
}

bool _isHidden(WidgetTester tester, String label) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, label),
        matching: find.byType(EditableText),
      ),
    )
    .obscureText;

class _TwoPasswords extends StatefulWidget {
  const _TwoPasswords();

  @override
  State<_TwoPasswords> createState() => _TwoPasswordsState();
}

class _TwoPasswordsState extends State<_TwoPasswords> {
  final TextEditingController _first = TextEditingController();
  final TextEditingController _second = TextEditingController();

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[
            PasswordField(
              controller: _first,
              label: 'First',
              textInputAction: TextInputAction.next,
            ),
            PasswordField(controller: _second, label: 'Second'),
          ],
        ),
      ),
    );
  }
}
