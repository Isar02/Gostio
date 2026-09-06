import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/theme/app_metrics.dart';
import 'package:gostio_mobile/core/widgets/rating_input.dart';

import '../../support/phone.dart';
import '../../support/widgets.dart';

void main() {
  setUp(usePhoneScreen);

  // A form that opened on a rating would collect it from everybody who left
  // the stars alone, so nothing is chosen until the reader chooses it.
  testWidgets('nothing is rated until a star is tapped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(RatingInput(rating: null, onChanged: (_) {})),
    );

    expect(find.text('Tap a star to rate what you booked.'), findsOneWidget);
    expect(
      find.byIcon(Icons.star_rounded),
      findsNothing,
      reason: 'an empty rating is five outlines rather than five filled stars',
    );
  });

  testWidgets('a tapped star answers with what it stands for', (
    WidgetTester tester,
  ) async {
    final List<int> chosen = <int>[];
    await tester.pumpWidget(
      drawn(RatingInput(rating: null, onChanged: chosen.add)),
    );

    await tester.tap(find.byType(IconButton).at(3));

    expect(chosen, <int>[4]);
  });

  testWidgets('a rating fills the stars up to it and says what it means', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(drawn(RatingInput(rating: 3, onChanged: (_) {})));

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(
      find.byIcon(Icons.star_outline_rounded),
      findsNWidgets(ReviewStars.highest - 3),
    );
    expect(find.text('Good'), findsOneWidget);
  });

  testWidgets('every star is a control a thumb can hit', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(drawn(RatingInput(rating: 2, onChanged: (_) {})));

    final Finder stars = find.byType(IconButton);

    for (int star = 0; star < ReviewStars.all.length; star++) {
      expect(
        tester.getSize(stars.at(star)),
        const Size(AppSizes.touchTarget, AppSizes.touchTarget),
      );
    }
  });
}
