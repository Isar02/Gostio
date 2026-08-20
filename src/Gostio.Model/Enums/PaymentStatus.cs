namespace Gostio.Model.Enums;

// Stored as its integer, so never renumber. There is no Failed: a declined card
// returns the Stripe intent to a reusable state, so the payment stays Pending.
public enum PaymentStatus
{
    Pending = 1,
    Succeeded = 2,
    Cancelled = 3
}
