using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database.Entities;
using Gostio.Services.Reports;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

// The rows are written to the tables rather than made through the endpoints
// that own them. A report is a question about reading, and a test that answers
// it through a booking flow fails twice when the booking flow breaks — and it
// could not place a charge in 2019 at all.
internal sealed class ReportWorkspace(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-a-reported-account";

    private readonly AccommodationWorkspace accommodations = new(fixture);

    public async Task<int> AListingAsync()
    {
        var (_, listing) = await accommodations.AListingAsync(Password);

        return listing;
    }

    public async Task<int> ABookingAsync(
        int listing,
        DateTime createdAt,
        decimal price = 500m,
        ReservationStatusCode status = ReservationStatusCode.Confirmed)
    {
        var guest = await fixture.AddUserAsync(Password);
        var checkIn = DateOnly.FromDateTime(createdAt).AddDays(30);

        await using var db = fixture.CreateContext();

        var reservation = new Reservation
        {
            UserId = guest,
            AccommodationId = listing,
            CheckInDate = checkIn,
            CheckOutDate = checkIn.AddDays(2),
            GuestCount = 2,
            ReservationStatusId = (int)status,
            ExpiresAt = createdAt.AddDays(1),
            AccommodationTotal = price,
            CleaningFee = 0m,
            TotalPrice = price,
            CreatedAt = createdAt,
        };

        db.Reservations.Add(reservation);

        await db.SaveChangesAsync();

        return reservation.Id;
    }

    public async Task CompletedAsync(int reservation, DateTime changedAt)
    {
        await using var db = fixture.CreateContext();

        db.ReservationStatusHistory.Add(new ReservationStatusHistory
        {
            ReservationId = reservation,
            PreviousStatusId = (int)ReservationStatusCode.Confirmed,
            NewStatusId = (int)ReservationStatusCode.Completed,
            ChangedAt = changedAt,
        });

        await db.SaveChangesAsync();
    }

    public async Task<int> AChargeAsync(
        int reservation,
        decimal amount,
        DateTime? processedAt,
        PaymentStatus status = PaymentStatus.Succeeded,
        string? currency = null)
    {
        await using var db = fixture.CreateContext();

        var payment = new Payment
        {
            ReservationId = reservation,
            StripePaymentIntentId = $"pi_{Guid.NewGuid():N}",
            Status = status,
            Amount = amount,
            Currency = currency ?? fixture.Stripe.Currency,
            CreatedAt = processedAt ?? DateTime.UtcNow,
            ProcessedAt = processedAt,
        };

        db.Payments.Add(payment);

        await db.SaveChangesAsync();

        return payment.Id;
    }

    public async Task ARefundAsync(
        int payment,
        decimal amount,
        DateTime? processedAt,
        RefundStatus status = RefundStatus.Succeeded)
    {
        await using var db = fixture.CreateContext();

        db.Refunds.Add(new Refund
        {
            PaymentId = payment,
            StripeRefundId = $"re_{Guid.NewGuid():N}",
            Status = status,
            Amount = amount,
            Reason = "A cancellation the policy paid back",
            CreatedAt = processedAt ?? DateTime.UtcNow,
            ProcessedAt = processedAt,
        });

        await db.SaveChangesAsync();
    }

    public async Task<RevenueReportResponse> RevenueAsync(DateOnly? from, DateOnly? to)
    {
        await using var services = fixture.BuildServices();

        return await services.GetRequiredService<IReportService>().RevenueAsync(
            new ReportRangeRequest { From = from, To = to }, default);
    }
}
