import 'package:flutter/services.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report_columns.dart';

// Either report as a printed document, landscape because eight columns of
// figures do not fit upright.
abstract final class ReportPdf {
  static Future<Uint8List> build<TRow, TTotals>({
    required String title,
    required String scope,
    required ReportDocument<TRow, TTotals> document,
    required List<ReportColumn<TRow, TTotals>> columns,
    DateTime? printedOn,
  }) async {
    final Map<int, pw.TableColumnWidth> widths = _widths(columns);
    final DateTime printed = printedOn ?? DateTime.now();
    final pw.Document pdf = pw.Document(theme: await theme(), title: title);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(_margin),
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            // The headings repeat on every page; this stands on the first.
            if (context.pageNumber == 1)
              _heading(
                title: title,
                scope: scope,
                from: document.from,
                to: document.to,
                printedOn: printed,
              ),
            _headings<TRow, TTotals>(columns, widths),
          ],
        ),
        footer: _footer,
        build: (pw.Context context) => <pw.Widget>[
          if (document.isEmpty)
            _nothing
          else
            _rows<TRow, TTotals>(document.rows, columns, widths),
          _totals<TRow, TTotals>(document.totals, columns, widths),
        ],
      ),
    );

    return pdf.save();
  }

  // Read once and held. The faces the package brings carry no letter with a
  // caron on it, and half the cities in the catalogue are spelt with one.
  static Future<pw.ThemeData> theme() async => _theme ??= _read();

  static Future<pw.ThemeData>? _theme;

  static Future<pw.ThemeData> _read() async => pw.ThemeData.withFont(
    base: pw.Font.ttf(await rootBundle.load(AppFonts.interfaceRegular)),
    bold: pw.Font.ttf(await rootBundle.load(AppFonts.interfaceSemiBold)),
  );

  static pw.Widget _heading({
    required String title,
    required String scope,
    required DateTime from,
    required DateTime to,
    required DateTime printedOn,
  }) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: _gap),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              'Gostio',
              style: pw.TextStyle(
                fontSize: _brandSize,
                fontWeight: pw.FontWeight.bold,
                color: _indigo,
              ),
            ),
            pw.SizedBox(height: _tight),
            pw.Text(title, style: const pw.TextStyle(fontSize: _titleSize)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: <pw.Widget>[
            pw.Text(scope, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: _tight),
            pw.Text(
              '${AppDates.day(from)} to ${AppDates.day(to)}',
              style: pw.TextStyle(color: _muted),
            ),
            pw.SizedBox(height: _tight),
            pw.Text(
              'Printed ${AppDates.dateTime(printedOn)}',
              style: pw.TextStyle(fontSize: _footnoteSize, color: _faint),
            ),
          ],
        ),
      ],
    ),
  );

  static pw.Widget _headings<TRow, TTotals>(
    List<ReportColumn<TRow, TTotals>> columns,
    Map<int, pw.TableColumnWidth> widths,
  ) => pw.Table(
    columnWidths: widths,
    children: <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: _ground,
          border: pw.Border(bottom: pw.BorderSide(color: _border)),
        ),
        children: <pw.Widget>[
          for (final ReportColumn<TRow, TTotals> column in columns)
            _cell(
              column.label,
              numeric: column.numeric,
              style: pw.TextStyle(
                fontSize: _labelSize,
                fontWeight: pw.FontWeight.bold,
                color: _muted,
              ),
            ),
        ],
      ),
    ],
  );

  static pw.Widget _rows<TRow, TTotals>(
    List<TRow> rows,
    List<ReportColumn<TRow, TTotals>> columns,
    Map<int, pw.TableColumnWidth> widths,
  ) => pw.Table(
    columnWidths: widths,
    children: <pw.TableRow>[
      for (final TRow row in rows)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _hairline)),
          ),
          children: <pw.Widget>[
            for (final ReportColumn<TRow, TTotals> column in columns)
              _cell(column.cell(row), numeric: column.numeric),
          ],
        ),
    ],
  );

  static pw.Widget _totals<TRow, TTotals>(
    TTotals totals,
    List<ReportColumn<TRow, TTotals>> columns,
    Map<int, pw.TableColumnWidth> widths,
  ) => pw.Table(
    columnWidths: widths,
    children: <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: _border, width: _rule),
          ),
        ),
        children: <pw.Widget>[
          for (final ReportColumn<TRow, TTotals> column in columns)
            _cell(
              column.total(totals),
              numeric: column.numeric,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
        ],
      ),
    ],
  );

  static pw.Widget _footer(pw.Context context) => pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: _gap),
    child: pw.Text(
      'Page ${context.pageNumber} of ${context.pagesCount}',
      style: pw.TextStyle(fontSize: _footnoteSize, color: _faint),
    ),
  );

  static pw.Widget get _nothing => pw.Container(
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.symmetric(vertical: _empty),
    child: pw.Text(
      'Nothing was booked in this range.',
      style: pw.TextStyle(color: _muted),
    ),
  );

  static pw.Widget _cell(
    String text, {
    required bool numeric,
    pw.TextStyle? style,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(
      horizontal: _cellPadding,
      vertical: _cellHeight,
    ),
    alignment: numeric ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    child: pw.Text(text, style: style),
  );

  static Map<int, pw.TableColumnWidth> _widths<TRow, TTotals>(
    List<ReportColumn<TRow, TTotals>> columns,
  ) => <int, pw.TableColumnWidth>{
    for (int index = 0; index < columns.length; index++)
      index: pw.FlexColumnWidth(columns[index].flex.toDouble()),
  };

  static PdfColor _of(Color colour) => PdfColor.fromInt(colour.toARGB32());

  static final PdfColor _indigo = _of(AppColors.indigoDeep);
  static final PdfColor _muted = _of(AppColors.inkMuted);
  static final PdfColor _faint = _of(AppColors.inkFaint);
  static final PdfColor _border = _of(AppColors.borderStrong);
  static final PdfColor _hairline = _of(AppColors.border);
  static final PdfColor _ground = _of(AppColors.hover);

  static const double _margin = 28;
  static const double _gap = 16;
  static const double _tight = 3;
  static const double _cellPadding = 6;
  static const double _cellHeight = 5;
  static const double _empty = 40;
  static const double _rule = 1.2;
  static const double _brandSize = 18;
  static const double _titleSize = 14;
  static const double _labelSize = 9;
  static const double _footnoteSize = 8;
}
