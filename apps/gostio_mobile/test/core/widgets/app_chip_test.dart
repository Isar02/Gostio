import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/theme/app_metrics.dart';
import 'package:gostio_mobile/core/widgets/app_chip.dart';

import '../../support/widgets.dart';

void main() {
  testWidgets('a chip reports being put on', (WidgetTester tester) async {
    int taps = 0;

    await tester.pumpWidget(
      drawn(Center(child: AppChip('Seaside', onTap: () => taps++))),
    );

    await tester.tap(find.byType(AppChip));
    await tester.pump();

    expect(taps, 1);
  });

  // A pill is shorter than a button, and a thumb is not.
  testWidgets('a chip is as tall as a thumb needs whatever it says', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(drawn(const Center(child: AppChip('Wi-Fi'))));

    expect(
      tester.getSize(find.byType(AppChip)).height,
      greaterThanOrEqualTo(AppSizes.touchTarget),
    );
  });

  // The cross is smaller than a thumb, so the pill answers for it rather than
  // showing a gesture only a cursor could make.
  testWidgets('a chip in force is taken off by tapping it anywhere', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    int removed = 0;

    await tester.pumpWidget(
      drawn(
        Center(child: AppChip.removable('Mostar', onRemove: () => removed++)),
      ),
    );

    expect(find.bySemanticsLabel('Remove Mostar'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byType(AppChip));
    await tester.pump();

    expect(removed, 1);

    semantics.dispose();
  });

  testWidgets('a chip that is not in force offers no way off', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(drawn(const Center(child: AppChip('Mostar'))));

    expect(find.bySemanticsLabel('Remove Mostar'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);

    semantics.dispose();
  });

  testWidgets('a chosen chip is drawn differently from an unchosen one', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        const Row(
          children: <Widget>[
            AppChip('Mountain', isSelected: true),
            AppChip('Luxury'),
          ],
        ),
      ),
    );

    final List<Color?> grounds = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(AppChip),
            matching: find.byType(Material),
          ),
        )
        .map((Material material) => material.color)
        .toList(growable: false);

    expect(grounds.first, isNot(grounds.last));
  });
}
