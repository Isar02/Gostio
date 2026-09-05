import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/theme/app_metrics.dart';
import 'package:gostio_mobile/core/widgets/month_grid.dart';

import '../../support/phone.dart';
import '../../support/widgets.dart';

void main() {
  setUp(usePhoneScreen);

  // September 2026 begins on a Tuesday and closes inside five weeks. August
  // begins on a Saturday and needs six, which is the month that broke a box
  // built to hold six weeks and nothing else.
  final DateTime sixWeekMonth = DateTime(2026, 8);

  Future<void> draw(
    WidgetTester tester, {
    DateTime? month,
    ValueChanged<DateTime>? onChosen,
    String? Function(DateTime day)? figureFor,
    bool Function(DateTime day)? isSold,
  }) async {
    await tester.pumpWidget(
      drawn(
        MonthGrid(
          month: month ?? DateTime(2026, 9),
          isTakeable: (DateTime _) => true,
          isSold: isSold ?? (DateTime _) => false,
          figureFor: figureFor,
          onChosen: onChosen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a month that prices its nights writes the figure under them', (
    WidgetTester tester,
  ) async {
    await draw(
      tester,
      figureFor: (DateTime day) => day.day == 15 ? '120' : '90',
    );

    expect(find.text('120'), findsOneWidget);
    expect(find.text('90'), findsWidgets);
  });

  // A calendar on a listing says what the month holds. Taking a range is a
  // gesture the booking screen offers, and a day that answers nothing must not
  // announce itself as something to press.
  testWidgets('a month with nothing to answer is read rather than pressed', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await draw(tester, figureFor: (DateTime _) => '90');

    expect(
      tester.getSemantics(find.text('15')).flagsCollection.isButton,
      isFalse,
    );

    semantics.dispose();
  });

  testWidgets('a month that answers hands back the day that was pressed', (
    WidgetTester tester,
  ) async {
    final List<DateTime> chosen = <DateTime>[];

    await draw(tester, onChosen: chosen.add);
    await tester.tap(find.text('15'));

    expect(chosen, <DateTime>[DateTime(2026, 9, 15)]);
  });

  // A night somebody else holds is struck through rather than merely dimmed,
  // which reads as a day that is simply late.
  testWidgets('a night already sold is struck through', (
    WidgetTester tester,
  ) async {
    await draw(tester, isSold: (DateTime day) => day.day == 15);

    expect(
      tester.widget<Text>(find.text('15')).style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(
      tester.widget<Text>(find.text('16')).style?.decoration,
      isNot(TextDecoration.lineThrough),
    );
  });

  // The days a week borrows from the month on either side hold their column
  // and draw nothing, so the weeks stay square whatever a cell carries.
  testWidgets('a priced month is drawn in the same weeks as a plain one', (
    WidgetTester tester,
  ) async {
    await draw(tester);
    final double plain = tester.getSize(find.byType(MonthGrid)).height;

    await draw(tester, figureFor: (DateTime _) => '90');
    final double priced = tester.getSize(find.byType(MonthGrid)).height;

    expect(priced, greaterThan(plain));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  // The weeks are not the whole grid: the weekdays above them are a row of
  // their own, so a caller holding a month to six cells' worth of height would
  // clip the last week of every month that needs six of them.
  testWidgets('a month of six weeks is taller than the six weeks in it', (
    WidgetTester tester,
  ) async {
    await draw(tester, month: sixWeekMonth, figureFor: (DateTime _) => '90');

    expect(find.text('31'), findsOneWidget);
    expect(
      tester.getSize(find.byType(MonthGrid)).height,
      greaterThan(AppSizes.calendarCellWithFigure * 6),
    );
  });
}
