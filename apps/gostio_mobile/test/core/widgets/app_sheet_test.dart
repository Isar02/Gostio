import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/widgets/app_sheet.dart';

import '../../support/widgets.dart';

void main() {
  testWidgets('a sheet names itself and draws what it was given', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      opener(
        (BuildContext context) => AppSheet.show<void>(
          context,
          title: 'Filters',
          builder: (BuildContext context) => const Text('Wi-Fi'),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsOneWidget);
  });

  testWidgets('a sheet carries the answer back to what opened it', (
    WidgetTester tester,
  ) async {
    String? chosen;

    await tester.pumpWidget(
      opener((BuildContext context) async {
        chosen = await AppSheet.show<String>(
          context,
          title: 'Category',
          builder: (BuildContext context) => TextButton(
            onPressed: () => Navigator.of(context).pop('Historic'),
            child: const Text('Historic'),
          ),
        );
      }),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historic'));
    await tester.pumpAndSettle();

    expect(chosen, 'Historic');
  });

  testWidgets('a sheet closes from its own bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      opener(
        (BuildContext context) => AppSheet.show<void>(
          context,
          title: 'Filters',
          builder: (BuildContext context) => const Text('Wi-Fi'),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsNothing);
  });

  // A sheet that has to be answered may not be left by the gesture that
  // dismisses an ordinary one, and it must not offer a close it does not obey.
  testWidgets('a sheet that must be answered offers no way out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      opener(
        (BuildContext context) => AppSheet.show<void>(
          context,
          title: 'Confirm the dates',
          isDismissible: false,
          builder: (BuildContext context) => const Text('Three nights'),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNothing);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Confirm the dates'), findsOneWidget);
  });

  testWidgets('a footer stays put while the body scrolls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      opener(
        (BuildContext context) => AppSheet.show<void>(
          context,
          title: 'Amenities',
          footer: const Text('Show 143 stays'),
          builder: (BuildContext context) => Column(
            children: <Widget>[
              for (int index = 0; index < 40; index++) Text('Amenity $index'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Show 143 stays'), findsOneWidget);

    await tester.drag(find.text('Amenity 0'), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('Show 143 stays'), findsOneWidget);
  });
}
