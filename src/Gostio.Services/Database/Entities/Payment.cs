using Gostio.Model.Enums;

namespace Gostio.Services.Database.Entities;

public class Payment
{
    public int Id { get; set; }

    public int ReservationId { get; set; }

    public Reservation Reservation { get; set; } = null!;

    // Null until Stripe issues the intent, unique from then on, which is what
    // stops a webhook delivered twice from becoming a second payment.
    public string? StripePaymentIntentId { get; set; }

    public PaymentStatus Status { get; set; } = PaymentStatus.Pending;

    // What the guest was actually charged. A refund is computed from this and
    // never from a price recalculated later.
    public decimal Amount { get; set; }

    public string Currency { get; set; } = null!;

    public DateTime CreatedAt { get; set; }

    // When the webhook resolved the payment, whichever way it went.
    public DateTime? ProcessedAt { get; set; }

    // The last decline, kept on a row that is still pending, because the guest
    // may try again on the same intent. Only the latest one is kept.
    public string? FailureReason { get; set; }
}
