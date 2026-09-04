import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/forms/form_fields.dart';

import '../../support/phone.dart';

void main() {
  setUp(usePhoneScreen);

  testWidgets('a refusal above the fold is brought back into view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _TallForm());

    await _scrollToTheBottom(tester);
    expect(_topOf(tester, 'First'), lessThan(0));

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('This one is needed.'), findsOneWidget);
    expect(_topOf(tester, 'First'), greaterThanOrEqualTo(0));
  });

  // The server faults by the name a field was sent under, and the fault is
  // shown on that field wherever down the form it sits.
  testWidgets('a field the server faulted is brought back into view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _TallForm());

    await _scrollToTheBottom(tester);

    tester.state<_TallFormState>(find.byType(_TallForm)).faultTheFirstField();
    await tester.pumpAndSettle();

    expect(_topOf(tester, 'First'), greaterThanOrEqualTo(0));
  });

  test('a field this form does not have is a mistake, not an empty answer', () {
    final FormFields fields = FormFields(<String>['first']);

    expect(() => fields['second'], throwsArgumentError);
  });
}

Future<void> _scrollToTheBottom(WidgetTester tester) async {
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -900));
  await tester.pumpAndSettle();
}

double _topOf(WidgetTester tester, String label) =>
    tester.getTopLeft(find.widgetWithText(TextFormField, label)).dy;

class _TallForm extends StatefulWidget {
  const _TallForm();

  @override
  State<_TallForm> createState() => _TallFormState();
}

class _TallFormState extends State<_TallForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final FormFields _fields = FormFields(<String>['first', 'second']);

  void faultTheFirstField() => _fields.revealFault(
    const ApiException(
      message: 'One or more values are not valid.',
      errors: <String, List<String>>{
        'First': <String>['The server will not take this.'],
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              children: <Widget>[
                TextFormField(
                  key: _fields['first'],
                  decoration: const InputDecoration(labelText: 'First'),
                  validator: (String? value) => value == null || value.isEmpty
                      ? 'This one is needed.'
                      : null,
                ),
                const SizedBox(height: 1200),
                TextFormField(
                  key: _fields['second'],
                  decoration: const InputDecoration(labelText: 'Second'),
                ),
                TextButton(
                  onPressed: () => _fields.validate(_form),
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
