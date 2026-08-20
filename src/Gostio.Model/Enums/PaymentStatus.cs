namespace Gostio.Model.Enums;

// Stored as the underlying integer, so these values must never be renumbered.
// There is no Failed: a declined card returns the Stripe intent to a reusable
// state rather than a terminal one, so the payment stays Pending and is retried
// against the same intent. Succeeded and Cancelled are the only ways out.
public enum PaymentStatus
{
    Pending = 1,
    Succeeded = 2,
    Cancelled = 3
}
