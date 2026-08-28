using Gostio.Model.Enums;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Reports;

internal sealed class RevenueReport(GostioDbContext db)
{
    public async Task<RevenueReportResponse> BuildAsync(
        ReportRange range,
        string whenNothingSettled,
        CancellationToken cancellationToken)
    {
        var from = range.FromUtc;
        var until = range.UntilUtc;

        var created = await CountByMonthAsync(
            db.Reservations
                .AsNoTracking()
                .Where(booking => booking.CreatedAt >= from && booking.CreatedAt < until)
                .Select(booking => booking.CreatedAt),
            cancellationToken);

        // The history row rather than the reservation: a booking carries the
        // status it holds now and not the moment it reached it.
        var completed = await CountByMonthAsync(
            db.ReservationStatusHistory
                .AsNoTracking()
                .Where(move => move.NewStatusId == (int)ReservationStatusCode.Completed)
                .Where(move => move.ChangedAt >= from && move.ChangedAt < until)
                .Select(move => move.ChangedAt),
            cancellationToken);

        // Grouped on the table and never on a projection of it: the provider
        // inlines a projected row into the key and then cannot translate it. The
        // currency belongs in that key, so the label comes out of the very rows
        // that carry the money — asked as a query of its own it would read a
        // different snapshot, and money settling in a second currency between
        // the two would be added up without anything catching it.
        var chargedRows = await db.Payments
            .AsNoTracking()
            .Where(payment => payment.Status == PaymentStatus.Succeeded)
            .Where(payment => payment.ProcessedAt >= from && payment.ProcessedAt < until)
            .GroupBy(payment => new
            {
                payment.ProcessedAt!.Value.Year,
                payment.ProcessedAt!.Value.Month,
                payment.Currency,
            })
            .Select(month => new MonthTotal(
                month.Key.Year,
                month.Key.Month,
                month.Key.Currency,
                month.Sum(payment => payment.Amount)))
            .ToListAsync(cancellationToken);

        var refundedRows = await db.Refunds
            .AsNoTracking()
            .Where(refund => refund.Status == RefundStatus.Succeeded)
            .Where(refund => refund.ProcessedAt >= from && refund.ProcessedAt < until)
            .GroupBy(refund => new
            {
                refund.ProcessedAt!.Value.Year,
                refund.ProcessedAt!.Value.Month,
                refund.Payment.Currency,
            })
            .Select(month => new MonthTotal(
                month.Key.Year,
                month.Key.Month,
                month.Key.Currency,
                month.Sum(refund => refund.Amount)))
            .ToListAsync(cancellationToken);

        var currency = ReportCurrency.RequireOne(
            chargedRows.Concat(refundedRows).Select(month => month.Currency),
            whenNothingSettled);

        var charged = Amounts(chargedRows);
        var refunded = Amounts(refundedRows);

        var rows = new List<RevenueReportRow>();

        foreach (var (year, month) in range.Months())
        {
            var chargedAmount = Amount(charged, year, month);
            var refundedAmount = Amount(refunded, year, month);

            rows.Add(new RevenueReportRow
            {
                Year = year,
                Month = month,
                BookingsCreated = Count(created, year, month),
                BookingsCompleted = Count(completed, year, month),
                GrossCharged = chargedAmount,
                Refunded = refundedAmount,
                Net = chargedAmount - refundedAmount,
            });
        }

        return new RevenueReportResponse
        {
            From = range.From,
            To = range.To,
            Currency = currency,
            Rows = rows,
            Totals = Add(rows),
        };
    }

    private static async Task<Dictionary<(int Year, int Month), int>> CountByMonthAsync(
        IQueryable<DateTime> moments,
        CancellationToken cancellationToken)
    {
        var months = await moments
            .GroupBy(moment => new { moment.Year, moment.Month })
            .Select(month => new MonthCount(month.Key.Year, month.Key.Month, month.Count()))
            .ToListAsync(cancellationToken);

        return months.ToDictionary(month => (month.Year, month.Month), month => month.Count);
    }

    private static Dictionary<(int Year, int Month), decimal> Amounts(
        IReadOnlyList<MonthTotal> months) =>
        months.ToDictionary(month => (month.Year, month.Month), month => month.Amount);

    private static int Count(
        Dictionary<(int Year, int Month), int> months, int year, int month) =>
        months.GetValueOrDefault((year, month));

    private static decimal Amount(
        Dictionary<(int Year, int Month), decimal> months, int year, int month) =>
        months.GetValueOrDefault((year, month));

    // Added up from the rows rather than asked of the database again, so a
    // total cannot disagree with the column standing above it.
    private static RevenueReportTotals Add(IReadOnlyList<RevenueReportRow> rows) =>
        new()
        {
            BookingsCreated = rows.Sum(row => row.BookingsCreated),
            BookingsCompleted = rows.Sum(row => row.BookingsCompleted),
            GrossCharged = rows.Sum(row => row.GrossCharged),
            Refunded = rows.Sum(row => row.Refunded),
            Net = rows.Sum(row => row.Net),
        };
}
