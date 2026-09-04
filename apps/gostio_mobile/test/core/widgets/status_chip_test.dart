import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/widgets/status_chip.dart';

import '../../support/widgets.dart';

void main() {
  testWidgets('a status is read in words as well as in colour', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(const StatusChip('Confirmed', tone: Tone.positive)),
    );

    expect(find.text('Confirmed'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Confirmed')).style?.color,
      Tone.positive.foreground,
    );
  });

  testWidgets('two statuses are told apart by their ground', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        const Row(
          children: <Widget>[
            StatusChip('Cancelled', tone: Tone.negative),
            StatusChip('Pending', tone: Tone.attention),
          ],
        ),
      ),
    );

    final List<Decoration?> grounds = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(StatusChip),
            matching: find.byType(Container),
          ),
        )
        .map((Container container) => container.decoration)
        .toList(growable: false);

    expect(grounds.first, isNot(grounds.last));
  });
}
