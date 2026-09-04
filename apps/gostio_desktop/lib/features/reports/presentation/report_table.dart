import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/widgets/record_table.dart';
import 'report_columns.dart';

class ReportTable<TRow, TTotals> extends StatelessWidget {
  const ReportTable({
    required this.document,
    required this.columns,
    required this.empty,
    super.key,
  });

  final ReportDocument<TRow, TTotals> document;
  final List<ReportColumn<TRow, TTotals>> columns;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    // Both lists are written from the same columns in the same order.
    final List<TableColumn<TRow>> drawn = <TableColumn<TRow>>[
      for (final ReportColumn<TRow, TTotals> column in columns)
        TableColumn<TRow>(
          label: column.label,
          cell: (BuildContext context, TRow row) => Text(column.cell(row)),
          flex: column.flex,
          numeric: column.numeric,
        ),
    ];

    return RecordTable<TRow>(
      columns: drawn,
      rows: document.rows,
      empty: empty,
      footer: TableSummaryRow<TRow>(
        columns: drawn,
        cells: <String>[
          for (final ReportColumn<TRow, TTotals> column in columns)
            column.total(document.totals),
        ],
      ),
    );
  }
}
