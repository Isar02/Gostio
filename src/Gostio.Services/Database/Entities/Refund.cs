using Gostio.Model.Enums;

namespace Gostio.Services.Database.Entities;

// Attached to the payment and to nothing else. The reservation is reachable
// through it, and a second path to the same row could disagree with the first.
public class Refund
{
    public int Id { get; set; }

    public int PaymentId { get; set; }

    public Payment Payment { get; set; } = null!;

    public string? StripeRefundId { get; set; }

    public RefundStatus Status { get; set; } = RefundStatus.Pending;

    // Taken from Payment.Amount and the cancellation policy, never from a price
    // worked out again from the listing.
    public decimal Amount { get; set; }

    // Which rule produced this amount, which is the part a guest disputes. The
    // reason for the cancellation itself belongs to its status history row.
    public string Reason { get; set; } = null!;

    public DateTime CreatedAt { get; set; }

    public DateTime? ProcessedAt { get; set; }

    public string? FailureReason { get; set; }
}
