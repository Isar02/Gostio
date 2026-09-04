import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/widgets/rating_stars.dart';

import '../../support/widgets.dart';

void main() {
  // Five empty stars read as a rating of nought rather than as no rating.
  testWidgets(
    'a listing nobody has reviewed says so instead of drawing nought',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        drawn(const RatingStars(rating: null, reviewCount: 0)),
      );

      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    },
  );

  testWidgets('a rating with no reviews behind it is not drawn as stars', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(const RatingStars(rating: 0, reviewCount: 0)),
    );

    expect(find.text('No reviews yet'), findsOneWidget);
  });

  // A count nobody supplied is unknown, not nought. A detail screen showing a
  // rating without one still has a rating to show.
  testWidgets('a rating with no count behind it is still drawn', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(drawn(const RatingStars(rating: 4.0)));

    expect(find.text('No reviews yet'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.text('4.0'), findsOneWidget);
  });

  testWidgets('a half is drawn as a half rather than rounded up', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(const RatingStars(rating: 4.5, reviewCount: 23)),
    );

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
  });

  testWidgets('a rating short of the half stays on the lower star', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(const RatingStars(rating: 4.2, reviewCount: 9)),
    );

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.star_half_rounded), findsNothing);
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
  });

  testWidgets('the figure and how many stand behind it are both read', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(const RatingStars(rating: 4.83, reviewCount: 23)),
    );

    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('(23)'), findsOneWidget);
  });

  testWidgets('the stars carry the rating for a reader who cannot see them', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      drawn(const RatingStars(rating: 4.0, reviewCount: 11)),
    );

    expect(find.bySemanticsLabel('4.0 out of 5'), findsOneWidget);

    semantics.dispose();
  });
}
