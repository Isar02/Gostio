import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/time/calendar_days.dart';
import 'reports_notifier.dart';

abstract final class ReportPrinting {
  // Everything that tells two documents apart is in the name.
  static String nameFor(ReportsNotifier reports) =>
      <String>[
        'gostio',
        reports.scope.slug,
        reports.kind.slug,
        if (reports.kind == ReportKind.listings) reports.catalogue.slug,
        CalendarDays.write(reports.range.from),
        CalendarDays.write(reports.range.to),
      ].join('-').toLowerCase() +
      _extension;

  static Future<void> toPrinter(Uint8List bytes, {required String name}) =>
      Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: name,
      );

  static Future<Uri?> toFile(Uint8List bytes, {required String name}) =>
      FilePicker.saveFile(
        fileName: name,
        bytes: bytes,
        mimeType: _mimeType,
        dialogTitle: 'Save the report',
        type: FileType.custom,
        allowedExtensions: <String>['pdf'],
      );

  static const String _extension = '.pdf';
  static const String _mimeType = 'application/pdf';
}
