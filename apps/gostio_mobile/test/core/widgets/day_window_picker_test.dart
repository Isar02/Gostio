import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/calendar/day_window.dart';
import 'package:gostio_mobile/core/widgets/day_window_picker.dart';

import '../../support/widgets.dart';

void main() {
  final DateTime june = DateTime(2026, 6);

  // One tap is already an answer here, which is the whole difference from the
  // picker a stay is chosen in.
  testWidgets('one tap is a window of a single day', (
    WidgetTester tester,
  ) async {
    DayWindow? chosen;

    await tester.pumpWidget(
      _picker(june, onChosen: (DayWindow? window) => chosen = window),
    );
    await _open(tester);

    await tester.tap(find.text('12'));
    await tester.pump();

    expect(find.text('One day'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(chosen, DayWindow.onOneDay(DateTime(2026, 6, 12)));
  });

  testWidgets('a later day widens the window rather than moving it', (
    WidgetTester tester,
  ) async {
    DayWindow? chosen;

    await tester.pumpWidget(
      _picker(june, onChosen: (DayWindow? window) => chosen = window),
    );
    await _open(tester);

    await tester.tap(find.text('12'));
    await tester.pump();
    await tester.tap(find.text('14'));
    await tester.pump();

    expect(find.text('3 days'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(
      chosen,
      DayWindow(from: DateTime(2026, 6, 12), to: DateTime(2026, 6, 14)),
    );
  });

  // A window that only ever widened could not be narrowed without being
  // cleared first, so the tap after it has widened starts again.
  testWidgets('a tap after the window was widened opens a new one', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_picker(june));
    await _open(tester);

    await tester.tap(find.text('12'));
    await tester.pump();
    await tester.tap(find.text('14'));
    await tester.pump();
    await tester.tap(find.text('16'));
    await tester.pump();

    expect(find.text('One day'), findsOneWidget);
    expect(find.text('16 Jun 2026'), findsOneWidget);
  });

  testWidgets('a tap before the day held opens a window there instead', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_picker(june));
    await _open(tester);

    await tester.tap(find.text('14'));
    await tester.pump();
    await tester.tap(find.text('12'));
    await tester.pump();

    expect(find.text('One day'), findsOneWidget);
    expect(find.text('12 Jun 2026'), findsOneWidget);
  });

  testWidgets('nothing can be applied before a day is chosen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_picker(june));
    await _open(tester);

    expect(find.text('Choose a day'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('a day before the first one offered is not takeable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_picker(DateTime(2026, 6, 10)));
    await _open(tester);

    await tester.tap(find.text('9'));
    await tester.pump();

    expect(find.text('Choose a day'), findsOneWidget);
  });

  testWidgets('a chosen window can be given back', (WidgetTester tester) async {
    await tester.pumpWidget(_picker(june));
    await _open(tester);

    await tester.tap(find.text('12'));
    await tester.pump();
    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(find.text('Choose a day'), findsOneWidget);
  });

  testWidgets('a picker opened on a window comes up holding it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _picker(
        june,
        selected: DayWindow(
          from: DateTime(2026, 6, 12),
          to: DateTime(2026, 6, 14),
        ),
      ),
    );
    await _open(tester);

    expect(find.text('3 days'), findsOneWidget);
  });

  testWidgets('a window that has fallen behind is not handed back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _picker(
        DateTime(2026, 6, 10),
        selected: DayWindow.onOneDay(DateTime(2026, 6, 8)),
      ),
    );
    await _open(tester);

    expect(find.text('Choose a day'), findsOneWidget);
  });
}

Widget _picker(
  DateTime firstDay, {
  DayWindow? selected,
  ValueChanged<DayWindow?>? onChosen,
}) => opener((BuildContext context) async {
  final DayWindow? chosen = await DayWindowPicker.show(
    context,
    selected: selected,
    firstDay: firstDay,
  );

  onChosen?.call(chosen);
});

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
