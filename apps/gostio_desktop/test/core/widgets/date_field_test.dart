import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/time/calendar_days.dart';
import 'package:gostio_desktop/core/widgets/date_field.dart';

void main() {
  testWidgets('a field with no day yet offers the calendar to pick one', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_field(value: null));
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The calendar refuses to open on a day outside the range it offers, and
  // today at midnight sits before a range that starts at this moment.
  testWidgets('today opens the calendar of a field that starts at today', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _field(value: CalendarDays.today(), firstDate: CalendarDays.today()),
    );

    // The field itself, rather than the button that takes the day off it.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a day that was chosen can be taken off again', (
    WidgetTester tester,
  ) async {
    DateTime? announced = CalendarDays.today();
    bool told = false;

    await tester.pumpWidget(
      _field(
        value: CalendarDays.today(),
        onChanged: (DateTime? day) {
          announced = day;
          told = true;
        },
      ),
    );
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(told, isTrue);
    expect(announced, isNull);
  });
}

Widget _field({
  required DateTime? value,
  DateTime? firstDate,
  ValueChanged<DateTime?>? onChanged,
}) => MaterialApp(
  home: Scaffold(
    body: DateField(
      value: value,
      firstDate: firstDate,
      onChanged: onChanged ?? (DateTime? _) {},
    ),
  ),
);
