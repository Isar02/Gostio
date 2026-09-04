import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/widgets/paged_list.dart';
import 'package:gostio_mobile/core/widgets/screen_states.dart';

import '../../support/widgets.dart';

void main() {
  testWidgets('nothing read yet and still reading is the wait', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(_list(<String>[], total: 0, isLoading: true)),
    );

    expect(find.byType(LoadingState), findsOneWidget);
  });

  testWidgets('nothing read and nothing to read says so', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        _list(<String>[], total: 0, emptyTitle: 'No stays match those filters'),
      ),
    );

    expect(find.text('No stays match those filters'), findsOneWidget);
  });

  testWidgets('nothing read because it was refused is the failure', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        _list(
          <String>[],
          total: 0,
          failureMessage: 'The search could not be read.',
          failureTraceId: '00-3f1a-9c',
        ),
      ),
    );

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Trace 00-3f1a-9c'), findsOneWidget);
  });

  // A list that grows under the reader with no figure beside it never says
  // where it ends.
  testWidgets('the list says how much of the whole is being held', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(_list(<String>['Old town loft', 'Kravice falls'], total: 143)),
    );

    expect(find.text('2 of 143 stays'), findsOneWidget);
  });

  testWidgets('the next page is asked for rather than taken', (
    WidgetTester tester,
  ) async {
    int asked = 0;

    await tester.pumpWidget(
      drawn(
        _list(<String>['Old town loft'], total: 143, onMore: () => asked++),
      ),
    );

    await tester.tap(find.text('Show more'));
    await tester.pump();

    expect(asked, 1);
  });

  testWidgets('a list holding everything offers no more', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(drawn(_list(<String>['Old town loft'], total: 1)));

    expect(find.text('Show more'), findsNothing);
    expect(find.text('1 of 1 stays'), findsOneWidget);
  });

  testWidgets('a page on its way is waited for under the list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(_list(<String>['Old town loft'], total: 143, isAppending: true)),
    );

    expect(find.text('Old town loft'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Show more'), findsNothing);
  });

  // What was already read is still true, so a page that failed to arrive may
  // not take it off the screen.
  testWidgets('a refused page leaves the list up and offers another go', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        _list(
          <String>['Old town loft'],
          total: 143,
          failureMessage: 'That page could not be read.',
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Old town loft'), findsOneWidget);
    expect(find.text('That page could not be read.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  // The list on screen belongs to the filter before the one that failed.
  // Asking for its next page would build one list out of two.
  testWidgets('another go retries the read rather than asking for more', (
    WidgetTester tester,
  ) async {
    int asked = 0;
    int retried = 0;

    await tester.pumpWidget(
      drawn(
        _list(
          <String>['Old town loft'],
          total: 143,
          failureMessage: 'The search could not be read.',
          onMore: () => asked++,
          onRetry: () => retried++,
        ),
      ),
    );

    expect(find.text('Show more'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(retried, 1);
    expect(asked, 0);
  });

  // A refusal is worth answering whether or not a page is left to fetch.
  testWidgets('a refusal on a whole list is still offered another go', (
    WidgetTester tester,
  ) async {
    int retried = 0;

    await tester.pumpWidget(
      drawn(
        _list(
          <String>['Old town loft'],
          total: 1,
          failureMessage: 'The search could not be read.',
          onRetry: () => retried++,
        ),
      ),
    );

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(retried, 1);
  });

  testWidgets('a header scrolls with the list rather than over it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        _list(
          <String>['Old town loft'],
          total: 1,
          header: const Text('Stays in Mostar'),
        ),
      ),
    );

    expect(find.text('Stays in Mostar'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Stays in Mostar')).dy,
      lessThan(tester.getCenter(find.text('Old town loft')).dy),
    );
  });
}

Widget _list(
  List<String> items, {
  required int total,
  bool isLoading = false,
  bool isAppending = false,
  String? failureMessage,
  String? failureTraceId,
  String emptyTitle = 'Nothing here yet',
  Widget? header,
  VoidCallback? onMore,
  VoidCallback? onRetry,
}) => PagedList<String>(
  items: items,
  totalCount: total,
  noun: 'stays',
  isLoading: isLoading,
  isAppending: isAppending,
  failureMessage: failureMessage,
  failureTraceId: failureTraceId,
  emptyTitle: emptyTitle,
  header: header,
  onMore: onMore ?? () {},
  onRetry: onRetry,
  itemBuilder: (BuildContext context, String item) => Text(item),
);
