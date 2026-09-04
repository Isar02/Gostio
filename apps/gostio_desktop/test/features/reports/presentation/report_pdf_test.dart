import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/reports/presentation/report_columns.dart';
import 'package:gostio_desktop/features/reports/presentation/report_pdf.dart';
import 'package:pdf/pdf.dart';

import '../../../support/report_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Half the cities in the catalogue are spelt with a caron or an acute, and a
  // face missing those letters prints the document with holes in it.
  test(
    'the printed face carries every letter the catalogue is spelt with',
    () async {
      for (final String path in <String>[
        AppFonts.interfaceRegular,
        AppFonts.interfaceSemiBold,
      ]) {
        final TtfParser face = TtfParser(await rootBundle.load(path));

        for (final int letter in 'ČčĆćŠšŽžĐđ—·'.runes) {
          expect(
            face.charToGlyphIndexMap.containsKey(letter),
            isTrue,
            reason: '$path has no glyph for ${String.fromCharCode(letter)}',
          );
        }
      }
    },
  );

  test('a report is written as a document with a page in it', () async {
    final Uint8List bytes =
        await ReportPdf.build<RevenueReportRow, RevenueReportTotals>(
          title: 'Revenue',
          scope: 'Platform',
          document: revenueReport(),
          columns: ReportColumns.revenue(revenueReport().currency),
          printedOn: DateTime(2026, 9, 3, 14, 22),
        );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(8)), startsWith('%PDF-'));
  });

  // A range nothing happened in is still a document: an empty one that says so
  // reads as an answer where a blank page reads as a failure.
  test('a report over a quiet range is still a document', () async {
    final Uint8List bytes =
        await ReportPdf.build<ListingReportRow, ListingReportTotals>(
          title: 'Listing performance',
          scope: 'My listings',
          document: listingReport(rows: const <ListingReportRow>[]),
          columns: ReportColumns.listings('bam', ListingKind.experience),
          printedOn: DateTime(2026, 9, 3, 14, 22),
        );

    expect(bytes, isNotEmpty);
  });
}
