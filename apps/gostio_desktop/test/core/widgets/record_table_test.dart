import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/widgets/pagination_footer.dart';
import 'package:gostio_desktop/core/widgets/record_table.dart';

void main() {
  testWidgets('a full page fits inside the table at the baseline size', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_table(rows: 20));

    expect(tester.takeException(), isNull);
    expect(find.byType(PaginationFooter), findsOneWidget);
    expect(find.text('Row 20'), findsOneWidget);

    final ScrollableState table = tester.state<ScrollableState>(
      find.byType(Scrollable),
    );
    expect(table.position.maxScrollExtent, 0);
  });
}

Widget _table({required int rows}) => MaterialApp(
  home: Scaffold(
    body: Column(
      children: <Widget>[
        // The height a filter bar and the shell's top bar leave behind.
        const SizedBox(height: 300),
        Expanded(
          child: RecordTable<int>(
            columns: <TableColumn<int>>[
              TableColumn<int>.text(
                label: 'Row',
                read: (int row) => 'Row $row',
              ),
            ],
            rows: <int>[for (int row = 1; row <= rows; row++) row],
            footer: PaginationFooter(
              page: 1,
              pageSize: rows,
              totalCount: rows,
              onPageChanged: (int _) {},
            ),
          ),
        ),
      ],
    ),
  ),
);
