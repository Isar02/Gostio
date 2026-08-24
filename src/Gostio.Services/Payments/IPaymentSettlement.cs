namespace Gostio.Services.Payments;

public enum PaymentOutcome
{
    Succeeded,
    Failed,
    Cancelled
}

// What the processor said about one charge, reduced to the three answers this
// application acts on. `FailureReason` is the processor's own words and belongs
// to `Failed` alone.
public sealed record PaymentOutcomeReport(
    string IntentId,
    PaymentOutcome Outcome,
    string? FailureReason);

public interface IPaymentSettlement
{
    Task SettleAsync(PaymentOutcomeReport report, CancellationToken cancellationToken);
}
