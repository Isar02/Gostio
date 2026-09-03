import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

@immutable
class TableColumn<T> {
  const TableColumn({
    required this.label,
    required this.cell,
    this.width,
    this.flex = 1,
    this.numeric = false,
  });

  factory TableColumn.text({
    required String label,
    required String Function(T row) read,
    double? width,
    int flex = 1,
  }) => TableColumn<T>(
    label: label,
    cell: (BuildContext context, T row) => Text(read(row)),
    width: width,
    flex: flex,
  );

  factory TableColumn.number({
    required String label,
    required String Function(T row) read,
    double width = AppSizes.numericColumn,
  }) => TableColumn<T>(
    label: label,
    cell: (BuildContext context, T row) => Text(read(row)),
    width: width,
    numeric: true,
  );

  final String label;
  final Widget Function(BuildContext context, T row) cell;
  final double? width;
  final int flex;
  final bool numeric;
}

class RecordTable<T> extends StatelessWidget {
  const RecordTable({
    required this.columns,
    required this.rows,
    this.onRowOpen,
    this.empty,
    this.footer,
    super.key,
  });

  final List<TableColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowOpen;
  final Widget? empty;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border, width: AppSizes.hairline),
      ),
      child: Column(
        children: <Widget>[
          _Header<T>(columns: columns),
          Expanded(
            child: rows.isEmpty
                ? empty ?? const _NothingToShow()
                : ListView.builder(
                    itemCount: rows.length,
                    itemExtent: AppSizes.tableRow,
                    itemBuilder: (BuildContext context, int index) => _Row<T>(
                      columns: columns,
                      row: rows[index],
                      onOpen: onRowOpen,
                    ),
                  ),
          ),
          if (footer case final Widget footer) footer,
        ],
      ),
    );
  }
}

class _Header<T> extends StatelessWidget {
  const _Header({required this.columns});

  final List<TableColumn<T>> columns;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: AppColors.inkMuted);

    return Container(
      height: AppSizes.tableHeaderRow,
      decoration: const BoxDecoration(
        color: AppColors.hover,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: AppSizes.hairline),
        ),
      ),
      child: Row(
        children: _laidOut<T>(
          columns,
          (int index, TableColumn<T> column) =>
              Text(column.label, style: style),
        ),
      ),
    );
  }
}

class _Row<T> extends StatelessWidget {
  const _Row({required this.columns, required this.row, this.onOpen});

  final List<TableColumn<T>> columns;
  final T row;
  final void Function(T row)? onOpen;

  @override
  Widget build(BuildContext context) {
    final TextStyle body =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

    return InkWell(
      // A row opens on a double click, which is what a desktop table does and
      // what keeps a single click free to mean nothing but a stop on the way.
      onDoubleTap: onOpen == null ? null : () => onOpen!(row),
      hoverColor: AppColors.hover,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.border,
              width: AppSizes.hairline,
            ),
          ),
        ),
        child: Row(
          children: _laidOut<T>(
            columns,
            (int index, TableColumn<T> column) => DefaultTextStyle(
              style: body,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              child: column.cell(context, row),
            ),
          ),
        ),
      ),
    );
  }
}

// A row under the rows, laid out on the same columns they are, so a figure
// that sums a column cannot drift out from under it.
class TableSummaryRow<T> extends StatelessWidget {
  const TableSummaryRow({required this.columns, required this.cells, super.key})
    : assert(
        columns.length == cells.length,
        'a summary says one thing per column',
      );

  final List<TableColumn<T>> columns;
  final List<String> cells;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.w600);

    return Container(
      height: AppSizes.footerRow,
      decoration: const BoxDecoration(
        color: AppColors.hover,
        border: Border(
          top: BorderSide(
            color: AppColors.borderStrong,
            width: AppSizes.stroke,
          ),
        ),
      ),
      child: Row(
        children: _laidOut<T>(
          columns,
          (int index, TableColumn<T> column) =>
              Text(cells[index], style: style),
        ),
      ),
    );
  }
}

class _NothingToShow extends StatelessWidget {
  const _NothingToShow();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Nothing to show.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

List<Widget> _laidOut<T>(
  List<TableColumn<T>> columns,
  Widget Function(int index, TableColumn<T> column) content,
) {
  return List<Widget>.generate(columns.length, (int index) {
    final TableColumn<T> column = columns[index];
    final Widget cell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Align(
        alignment: column.numeric
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: content(index, column),
      ),
    );

    return column.width == null
        ? Expanded(flex: column.flex, child: cell)
        : SizedBox(width: column.width, child: cell);
  }, growable: false);
}
