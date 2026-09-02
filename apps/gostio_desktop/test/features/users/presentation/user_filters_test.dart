import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/reference/data/lookup_item.dart';
import 'package:gostio_desktop/features/users/data/user_query.dart';
import 'package:gostio_desktop/features/users/presentation/user_filter_options.dart';
import 'package:gostio_desktop/features/users/presentation/user_filters.dart';

void main() {
  // The API matches the role by its name rather than by the row's id, so what
  // the dropdown holds is a lookup and what it sends is the word on it.
  testWidgets('a role goes out under its own name', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();

    await tester.pumpWidget(harness.build());
    await harness.choose(tester, 'Any role', 'Host');

    expect(harness.announced?.role, 'Host');
    expect(harness.announced?.toParameters(), <String, dynamic>{
      'role': 'Host',
    });
  });

  testWidgets('a filter that did not load goes back off the controls', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();

    await tester.pumpWidget(harness.build());
    await harness.choose(tester, 'All', 'Deactivated');

    expect(harness.announced?.isActive, isFalse);

    // The request failed, so the rows are still the ones the empty query
    // fetched and the notifier's query never moved.
    await harness.settle(tester, const UserQuery());

    expect(find.text('Deactivated'), findsNothing);
  });

  testWidgets('clearing takes every filter off at once', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness(
      applied: const UserQuery(
        name: 'Lamija',
        username: 'lamija.h',
        email: 'gostio',
        role: 'Host',
        isActive: true,
      ),
    );

    await tester.pumpWidget(harness.build());
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(harness.announced?.isEmpty, isTrue);
    expect(find.text('Any role'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });
}

class _Harness {
  _Harness({this.applied = const UserQuery()});

  static const UserFilterOptions options = UserFilterOptions(
    roles: <LookupItem>[
      LookupItem(id: 1, name: 'Administrator'),
      LookupItem(id: 2, name: 'Host'),
      LookupItem(id: 3, name: 'Guest'),
    ],
  );

  UserQuery applied;
  bool isLoading = false;
  UserQuery? announced;

  late StateSetter _rebuild;

  Widget build() => MaterialApp(
    home: Scaffold(
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          _rebuild = setState;

          return UserFilters(
            options: options,
            applied: applied,
            isLoading: isLoading,
            onChanged: (UserQuery query) => announced = query,
          );
        },
      ),
    ),
  );

  Future<void> choose(WidgetTester tester, String from, String option) async {
    await tester.tap(find.text(from).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();

    _rebuild(() => isLoading = true);
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester, UserQuery query) async {
    _rebuild(() {
      applied = query;
      isLoading = false;
    });
    await tester.pumpAndSettle();
  }
}
