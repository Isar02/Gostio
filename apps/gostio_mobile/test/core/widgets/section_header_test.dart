import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/widgets/section_header.dart';

import '../../support/widgets.dart';

void main() {
  testWidgets('a header names what follows it', (WidgetTester tester) async {
    await tester.pumpWidget(
      drawn(
        const SectionHeader('Stays in Mostar', subtitle: '143 places to stay'),
      ),
    );

    expect(find.text('Stays in Mostar'), findsOneWidget);
    expect(find.text('143 places to stay'), findsOneWidget);
  });

  testWidgets('a header without an action draws no button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(drawn(const SectionHeader('Stays in Mostar')));

    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('a header opens what it points at', (WidgetTester tester) async {
    int opened = 0;

    await tester.pumpWidget(
      drawn(
        SectionHeader(
          'Recommended for you',
          actionLabel: 'See all',
          onAction: () => opened++,
        ),
      ),
    );

    await tester.tap(find.text('See all'));
    await tester.pump();

    expect(opened, 1);
  });
}
