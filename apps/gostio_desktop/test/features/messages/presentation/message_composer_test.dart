import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/messages/presentation/message_composer.dart';

void main() {
  testWidgets('Enter sends what is written', (WidgetTester tester) async {
    final List<String> sent = <String>[];
    await tester.pumpWidget(_composer(sent));

    await tester.enterText(find.byType(TextField), 'It arrived this morning.');
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(sent, <String>['It arrived this morning.']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  // A message runs to two thousand characters, so writing a line inside one
  // has to be possible without sending it.
  testWidgets('Shift and Enter write a line rather than sending', (
    WidgetTester tester,
  ) async {
    final List<String> sent = <String>[];
    await tester.pumpWidget(_composer(sent));

    await tester.enterText(find.byType(TextField), 'The first line');
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    expect(sent, isEmpty);
  });

  // The server keys its refusal by the field it bound, and a field's message
  // belongs under the control rather than in a notice over the form.
  testWidgets('what the server refused the field for is said under the box', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _composer(<String>[], refusal: 'A message needs something in it.'),
    );

    expect(find.text('A message needs something in it.'), findsOneWidget);
  });

  test('a message longer than the server takes is refused first', () {
    expect(
      Validators.messageBody('a' * (Validators.messageBodyMaximum + 1)),
      'A message is at most ${Validators.messageBodyMaximum} characters long.',
    );
    expect(Validators.messageBody('   '), 'A message needs something in it.');
    expect(Validators.messageBody('Yes.'), isNull);
  });

  // A limit nobody is near is a number in the way, so the count appears only
  // once the message is long enough to be worth watching.
  testWidgets('the count appears once the message is long', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_composer(<String>[]));

    await tester.enterText(find.byType(TextField), 'Short.');
    await tester.pumpAndSettle();

    expect(find.textContaining('of 2000'), findsNothing);

    await tester.enterText(
      find.byType(TextField),
      'a' * MessageComposer.countedFrom,
    );
    await tester.pumpAndSettle();

    expect(find.text('${MessageComposer.countedFrom} of 2000'), findsOneWidget);
  });
}

Widget _composer(List<String> sent, {String? refusal}) => MaterialApp(
  home: Scaffold(
    body: MessageComposer(
      hint: 'Answer the request',
      isSending: false,
      refusal: refusal,
      onSend: (String body) async {
        sent.add(body);

        return true;
      },
    ),
  ),
);
