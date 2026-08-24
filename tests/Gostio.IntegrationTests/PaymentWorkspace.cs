using Gostio.Model.Enums;
using Gostio.Model.Responses;
using Gostio.Services.Payments;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

internal sealed record StoredPayment(
    int Id,
    PaymentStatus Status,
    decimal Amount,
    string Currency,
    string? StripePaymentIntentId,
    DateTime? ProcessedAt,
    string? FailureReason);

internal sealed record StoredRefund(
    int Id,
    int PaymentId,
    RefundStatus Status,
    decimal Amount,
    string Reason,
    string? StripeRefundId,
    DateTime CreatedAt,
    DateTime? ProcessedAt,
    string? FailureReason);

internal sealed class PaymentWorkspace(DatabaseFixture fixture)
{
    public FakePaymentGateway Gateway { get; } = new();

    public ReservationWorkspace Reservations { get; } = new(fixture);

    public Task<PaymentResponse> StartAsync(
        int actor,
        string role,
        int reservationId,
        params IInterceptor[] interceptors) =>
        AsAsync(
            actor,
            role,
            service => service.StartAsync(reservationId, default),
            interceptors);

    public Task<PaymentResponse> ReadAsync(int actor, string role, int reservationId) =>
        AsAsync(actor, role, service => service.GetAsync(reservationId, default));

    public async Task SettleAsync(PaymentOutcomeReport report)
    {
        await using var services = fixture.BuildServices(caller: null, Gateway);

        await services.GetRequiredService<IPaymentSettlement>().SettleAsync(report, default);
    }

    public async Task ReceiveAsync(string payload, string? signature)
    {
        await using var services = fixture.BuildServices(caller: null, Gateway);

        await services.GetRequiredService<IPaymentWebhook>()
            .ReceiveAsync(payload, signature, default);
    }

    public async Task<IReadOnlyList<StoredPayment>> PaymentsOfAsync(int reservationId)
    {
        await using var db = fixture.CreateContext();

        return await db.Payments
            .AsNoTracking()
            .Where(payment => payment.ReservationId == reservationId)
            .OrderBy(payment => payment.Id)
            .Select(payment => new StoredPayment(
                payment.Id,
                payment.Status,
                payment.Amount,
                payment.Currency,
                payment.StripePaymentIntentId,
                payment.ProcessedAt,
                payment.FailureReason))
            .ToListAsync();
    }

    public Task SucceedAsync(int paymentId) =>
        SettleAsync(new PaymentOutcomeReport(
            FakePaymentGateway.IntentOf(paymentId), PaymentOutcome.Succeeded, null));

    private async Task<PaymentResponse> AsAsync(
        int actor,
        string role,
        Func<IPaymentService, Task<PaymentResponse>> work,
        params IInterceptor[] interceptors)
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(actor, role), Gateway, interceptors);

        return await work(services.GetRequiredService<IPaymentService>());
    }
}
