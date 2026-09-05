import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/calendar/date_range.dart';
import 'package:gostio_mobile/core/theme/app_metrics.dart';
import 'package:gostio_mobile/core/widgets/date_range_picker.dart';

import '../../support/widgets.dart';

void main() {
  final DateTime june = DateTime(2026, 6);

  testWidgets('a range is two taps and an apply', (WidgetTester tester) async {
    DateRange? chosen;

    await tester.pumpWidget(
      _picker(june, onChosen: (DateRange? range) => chosen = range),
    );
    await _open(tester);

    await tester.tap(find.text('12'));
    await tester.pump();
    await tester.tap(find.text('15'));
    await tester.pump();

    expect(find.text('3 nights'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(
      chosen,
      DateRange(from: DateTime(2026, 6, 12), to: DateTime(2026, 6, 15)),
    );
  });

  testWidgets('nothing can be applied before both ends are chosen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_picker(june));
    await _open(tester);

    expect(find.text('Choose a first night'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('12'));
    await tester.pump();

    expect(find.text('Choose a last night'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  // A second tap that cannot close a range opens a new one, rather than
  // swallowing the gesture and leaving the reader wondering.
  testWidgets('a tap before the first night starts again from there', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_picker(june));
    await _open(tester);

    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('12'));
    await tester.pump();

    expect(find.text('Choose a last night'), findsOneWidget);
    expect(find.text('12 Jun 2026'), findsOneWidget);
  });

  // The server owns availability; refusing here saves the reader committing
  // to a stay it will not sell.
  testWidgets('a night already sold cannot be chosen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _picker(june, unavailable: <DateTime>{DateTime(2026, 6, 13)}),
    );
    await _open(tester);

    await tester.tap(find.text('13'));
    await tester.pump();

    expect(find.text('Choose a first night'), findsOneWidget);
  });

  testWidgets('a range may not be drawn across a night somebody else holds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _picker(june, unavailable: <DateTime>{DateTime(2026, 6, 13)}),
    );
    await _open(tester);

    await tester.tap(find.text('12'));
    await tester.pump();
    await tester.tap(find.text('15'));
    await tester.pump();

    expect(find.text('3 nights'), findsNothing);
    expect(find.text('15 Jun 2026'), findsOneWidget);
  });

  // The stay ends on the day the reader leaves, and that day is free for the
  // next one, so a sold night there does not block the range.
  testWidgets('a night sold on the day of leaving does not block the stay', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _picker(june, unavailable: <DateTime>{DateTime(2026, 6, 15)}),
    );
    await _open(tester);

    await tester.tap(find.text('12'));
    await tester.pump();
    await tester.tap(find.text('15'));
    await tester.pump();

    expect(find.text('3 nights'), findsOneWidget);
  });

  testWidgets('nothing before the first day the listing takes is offered', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_picker(DateTime(2026, 6, 10)));
    await _open(tester);

    await tester.tap(find.text('9'));
    await tester.pump();

    expect(find.text('Choose a first night'), findsOneWidget);
  });

  testWidgets('the month before the first the listing takes is not offered', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_picker(june));
    await _open(tester);

    expect(find.text('June 2026'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.chevron_left),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('the next month is a month further on', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_picker(june));
    await _open(tester);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('July 2026'), findsOneWidget);
  });

  testWidgets('a chosen range can be given back', (WidgetTester tester) async {
    await tester.pumpWidget(_picker(june));
    await _open(tester);

    await tester.tap(find.text('12'));
    await tester.pump();
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(find.text('Choose a first night'), findsOneWidget);
  });

  testWidgets('leaving changed dates asks before discarding them', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_picker(june));
    await _open(tester);

    await tester.tap(find.text('12'));
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Leave these dates?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('12 Jun 2026'), findsOneWidget);
  });

  testWidgets('changed dates cannot be dragged away', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_picker(june));
    await _open(tester);

    await tester.tap(find.text('12'));
    await tester.pump();
    await tester.drag(find.text('Choose your dates'), const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(find.text('Choose a last night'), findsOneWidget);
  });

  testWidgets('a picker opened on a range comes up holding it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _picker(
        june,
        selected: DateRange(
          from: DateTime(2026, 6, 12),
          to: DateTime(2026, 6, 15),
        ),
      ),
    );
    await _open(tester);

    expect(find.text('3 nights'), findsOneWidget);
  });

  // Availability moves while the reader is elsewhere. A range chosen before
  // one of its nights was sold may not come back ready to be applied.
  testWidgets('a range that has since been sold is not handed back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _picker(
        june,
        selected: DateRange(
          from: DateTime(2026, 6, 12),
          to: DateTime(2026, 6, 15),
        ),
        unavailable: <DateTime>{DateTime(2026, 6, 13)},
      ),
    );
    await _open(tester);

    expect(find.text('3 nights'), findsNothing);
    expect(find.text('Choose a first night'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('a range that starts before the listing takes one is dropped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _picker(
        DateTime(2026, 6, 10),
        selected: DateRange(
          from: DateTime(2026, 6, 8),
          to: DateTime(2026, 6, 12),
        ),
      ),
    );
    await _open(tester);

    expect(find.text('Choose a first night'), findsOneWidget);
  });

  // A day is a control, and a control is measured for a thumb. Seven of them
  // across the narrowest phone the client is drawn on is what the grid's side
  // padding was set from, so that is the width this is checked at.
  testWidgets('a day is a thumb across on the narrowest phone', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_picker(june));
    await _open(tester);

    final Size day = tester.getSize(
      find.ancestor(of: find.text('12'), matching: find.byType(SizedBox)).first,
    );

    expect(day.height, greaterThanOrEqualTo(AppSizes.touchTarget));
    expect(day.width, greaterThanOrEqualTo(AppSizes.touchTarget));
  });
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Widget _picker(
  DateTime firstDay, {
  DateRange? selected,
  Set<DateTime> unavailable = const <DateTime>{},
  ValueChanged<DateRange?>? onChosen,
}) => opener((BuildContext context) async {
  final DateRange? chosen = await DateRangePicker.show(
    context,
    firstDay: firstDay,
    selected: selected,
    unavailable: unavailable,
  );

  onChosen?.call(chosen);
});
