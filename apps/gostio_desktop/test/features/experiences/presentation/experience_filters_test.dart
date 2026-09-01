import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/experiences/data/experience_query.dart';
import 'package:gostio_desktop/features/experiences/presentation/experience_filter_options.dart';
import 'package:gostio_desktop/features/experiences/presentation/experience_filters.dart';
import 'package:gostio_desktop/features/reference/data/lookup_item.dart';

void main() {
  testWidgets('a filter that did not load goes back off the controls', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();

    await tester.pumpWidget(harness.build());
    await harness.chooseCity(tester, 'Mostar');

    expect(harness.announced?.cityId, 2);

    // The request failed, so the rows are still the ones the empty query
    // fetched and the notifier's query never moved.
    await harness.settle(tester, const ExperienceQuery());

    expect(find.text('Mostar'), findsNothing);
    expect(find.text('Any'), findsWidgets);
  });

  testWidgets('a filter that loaded stays on the controls', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();

    await tester.pumpWidget(harness.build());
    await harness.chooseCity(tester, 'Mostar');

    await harness.settle(tester, harness.announced!);

    expect(find.text('Mostar'), findsOneWidget);
  });

  testWidgets('an older failed request does not erase a newer draft', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();

    await tester.pumpWidget(harness.build());
    await harness.chooseCity(tester, 'Mostar');
    await tester.enterText(find.byType(TextField).first, 'Rafting');

    await harness.finish(tester, const ExperienceQuery());

    expect(find.text('Rafting'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));

    expect(harness.announced?.title, 'Rafting');
    expect(harness.announced?.cityId, 2);
  });
}

class _Harness {
  static const ExperienceFilterOptions options = ExperienceFilterOptions(
    cities: <LookupItem>[
      LookupItem(id: 1, name: 'Sarajevo'),
      LookupItem(id: 2, name: 'Mostar'),
    ],
    categories: <LookupItem>[],
  );

  ExperienceQuery applied = const ExperienceQuery();
  bool isLoading = false;
  ExperienceQuery? announced;

  late StateSetter _rebuild;

  Widget build() => MaterialApp(
    home: Scaffold(
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          _rebuild = setState;

          return ExperienceFilters(
            options: options,
            applied: applied,
            isLoading: isLoading,
            onChanged: (ExperienceQuery query) => announced = query,
          );
        },
      ),
    ),
  );

  Future<void> chooseCity(WidgetTester tester, String name) async {
    await tester.tap(find.text('Any').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();

    _rebuild(() => isLoading = true);
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester, ExperienceQuery query) async {
    await finish(tester, query);
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester, ExperienceQuery query) async {
    _rebuild(() {
      applied = query;
      isLoading = false;
    });
    await tester.pump();
  }
}
