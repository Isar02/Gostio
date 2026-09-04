import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/widgets/screen_states.dart';

import '../../support/widgets.dart';

void main() {
  testWidgets('a loading state says what is being waited for when it knows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(drawn(const LoadingState(message: 'Searching')));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Searching'), findsOneWidget);
  });

  testWidgets('an empty state offers the way out of being empty', (
    WidgetTester tester,
  ) async {
    int cleared = 0;

    await tester.pumpWidget(
      drawn(
        EmptyState(
          title: 'No stays match those filters',
          message: 'Try a wider date range or fewer amenities.',
          action: OutlinedButton(
            onPressed: () => cleared++,
            child: const Text('Clear filters'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Clear filters'));
    await tester.pump();

    expect(cleared, 1);
    expect(find.text('No stays match those filters'), findsOneWidget);
  });

  testWidgets('an error state can be tried again', (WidgetTester tester) async {
    int retries = 0;

    await tester.pumpWidget(
      drawn(
        ErrorState(
          message: 'The search could not be read.',
          onRetry: () => retries++,
        ),
      ),
    );

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('an error nobody can retry offers no button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(const ErrorState(message: 'The search could not be read.')),
    );

    expect(find.text('Try again'), findsNothing);
  });

  // The same id is in the server's log, so it has to leave the screen.
  testWidgets('a failure carries its trace where it can be copied', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        const ErrorState(
          message: 'The search could not be read.',
          traceId: '00-3f1a-9c',
        ),
      ),
    );

    expect(find.text('Trace 00-3f1a-9c'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });
}
