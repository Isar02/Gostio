import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/reviews/presentation/rating_stars.dart';

void main() {
  testWidgets('a rating fills as many marks as it was given', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RatingStars(3))),
    );

    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byIcon(Icons.star_outline), findsNWidgets(2));
  });

  // Five small marks are quick to miscount, so the number is said in words to
  // whoever holds the pointer over them.
  testWidgets('the figure is said out loud beside the marks', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RatingStars(4))),
    );

    expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, '4 out of 5');
  });
}
