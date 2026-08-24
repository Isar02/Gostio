using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Reservations;
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

    public async Task<IReadOnlyList<StoredRefund>> RefundsOfAsync(int reservationId)
    {
        await using var db = fixture.CreateContext();

        return await db.Refunds
            .AsNoTracking()
            .Where(refund => refund.Payment.ReservationId == reservationId)
            .OrderBy(refund => refund.Id)
            .Select(refund => new StoredRefund(
                refund.Id,
                refund.PaymentId,
                refund.Status,
                refund.Amount,
                refund.Reason,
                refund.StripeRefundId,
                refund.CreatedAt,
                refund.ProcessedAt,
                refund.FailureReason))
            .ToListAsync();
    }

    // A refund follows the amount that was taken and not the price on the
    // booking, so a test moves one away from the other to see which it reads.
    public async Task ChargeAsync(int paymentId, decimal amount)
    {
        await using var db = fixture.CreateContext();

        await db.Payments
            .Where(payment => payment.Id == paymentId)
            .ExecuteUpdateAsync(setters => setters.SetProperty(payment => payment.Amount, amount));
    }

    public async Task<RefundSweepReport> SweepRefundsAsync(int batch = 50)
    {
        await using var services = fixture.BuildRefundSweep(Gateway, batch);

        return await services.GetRequiredService<IRefundSweep>().RunAsync(default);
    }

    // Settles whatever earlier suites left owed, through a processor of its own,
    // so what this workspace's own gateway is asked afterwards is only its own.
    public async Task DrainRefundsAsync()
    {
        await using var services = fixture.BuildRefundSweep(new FakePaymentGateway(), batch: 1000);

        await services.GetRequiredService<IRefundSweep>().RunAsync(default);
    }

    public async Task<RefundResponse> ReadRefundAsync(int actor, string role, int reservationId)
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(actor, role), Gateway);

        return await services.GetRequiredService<IRefundService>()
            .GetAsync(reservationId, default);
    }

    public async Task<RefundQuoteResponse> QuoteAsync(int actor, string role, int reservationId)
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(actor, role), Gateway);

        return await services.GetRequiredService<IRefundService>()
            .QuoteAsync(reservationId, default);
    }

    // Runs a cancellation and a settlement at the same instant, released together
    // on the lock they both take, which is the only place the two can collide.
    public async Task<(Task Cancel, Task Settle)> CancelWhileSettlingAsync(
        int actor,
        string role,
        int reservationId,
        int paymentId)
    {
        var barrier = new CommandBarrier(2, "[Reservations] WITH (UPDLOCK, HOLDLOCK)");

        var cancel = CancelUnderAsync(actor, role, reservationId, barrier);
        var settle = SettleUnderAsync(paymentId, barrier);

        await Task.WhenAll(cancel, settle);

        return (cancel, settle);
    }

    public Task SucceedAsync(int paymentId) =>
        SettleAsync(new PaymentOutcomeReport(
            FakePaymentGateway.IntentOf(paymentId), PaymentOutcome.Succeeded, null));

    private async Task CancelUnderAsync(
        int actor,
        string role,
        int reservationId,
        IInterceptor barrier)
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(actor, role), Gateway, barrier);

        await services.GetRequiredService<IReservationMoveService>().CancelAsync(
            reservationId, new ReservationCancelRequest { Reason = "Plans changed" }, default);
    }

    private async Task SettleUnderAsync(int paymentId, IInterceptor barrier)
    {
        await using var services = fixture.BuildServices(caller: null, Gateway, barrier);

        await services.GetRequiredService<IPaymentSettlement>().SettleAsync(
            new PaymentOutcomeReport(
                FakePaymentGateway.IntentOf(paymentId), PaymentOutcome.Succeeded, null),
            default);
    }

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
