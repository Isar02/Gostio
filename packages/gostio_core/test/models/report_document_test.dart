import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

void main() {
  test('a month of trade is read with its four figures', () {
    final RevenueReport report = RevenueReport.fromJson(
      <String, dynamic>{
        'from': '2026-07-01',
        'to': '2026-08-31',
        'currency': 'bam',
        'rows': <dynamic>[
          <String, dynamic>{
            'year': 2026,
            'month': 7,
            'bookingsCreated': 12,
            'bookingsCompleted': 9,
            'grossCharged': 4920.25,
            'refunded': 210,
            'net': 4710.25,
          },
        ],
        'totals': <String, dynamic>{
          'bookingsCreated': 12,
          'bookingsCompleted': 9,
          'grossCharged': 4920.25,
          'refunded': 210,
          'net': 4710.25,
        },
      },
      (Object? row) => RevenueReportRow.fromJson(row! as Map<String, dynamic>),
      (Object? totals) =>
          RevenueReportTotals.fromJson(totals! as Map<String, dynamic>),
    );

    expect(report.from, DateTime(2026, 7));
    expect(report.to, DateTime(2026, 8, 31));
    expect(report.currency, 'bam');
    expect(report.rows.single.monthStart, DateTime(2026, 7));
    expect(report.rows.single.net, 4710.25);
    expect(report.totals.refunded, 210);
    expect(report.isEmpty, isFalse);
  });

  // A row nothing was reviewed in answers no rating at all rather than a zero
  // that would read as the worst score there is.
  test('a row with nothing reviewed carries no rating', () {
    final ListingReportRow row = ListingReportRow.fromJson(<String, dynamic>{
      'cityId': 2,
      'city': 'Mostar',
      'categoryId': 1,
      'category': 'Apartment',
      'listingsPublished': 3,
      'bookings': 0,
      'unitsSold': 0,
      'grossCharged': 0,
      'averageRating': null,
      'reviewCount': 0,
    });

    expect(row.averageRating, isNull);
    expect(row.grossCharged, 0);
  });

  test('a report over a quiet range is read as a document with no rows', () {
    final ListingReport report = ListingReport.fromJson(
      <String, dynamic>{
        'from': '2026-07-01',
        'to': '2026-07-31',
        'target': 'Experiences',
        'currency': 'bam',
        'rows': <dynamic>[],
        'totals': <String, dynamic>{
          'listingsPublished': 0,
          'bookings': 0,
          'unitsSold': 0,
          'grossCharged': 0,
          'averageRating': null,
          'reviewCount': 0,
        },
      },
      (Object? row) => ListingReportRow.fromJson(row! as Map<String, dynamic>),
      (Object? totals) =>
          ListingReportTotals.fromJson(totals! as Map<String, dynamic>),
    );

    expect(report.isEmpty, isTrue);
    expect(report.totals.averageRating, isNull);
  });
}
