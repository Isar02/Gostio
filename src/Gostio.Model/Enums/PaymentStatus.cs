namespace Gostio.Model.Enums;

// Stored as the underlying integer, so these values must never be renumbered.
// Each one is the resting place of a Stripe payment intent event.
public enum PaymentStatus
{
    Pending = 1,
    Succeeded = 2,
    Failed = 3,
    Cancelled = 4
}
