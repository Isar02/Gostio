using Gostio.Model.Enums;

namespace Gostio.Services.Database.Entities;

public class Refund
{
    public int Id { get; set; }

    public int PaymentId { get; set; }

    public Payment Payment { get; set; } = null!;

    public string? StripeRefundId { get; set; }

    public RefundStatus Status { get; set; } = RefundStatus.Pending;

    public decimal Amount { get; set; }

    public string Reason { get; set; } = null!;

    public DateTime CreatedAt { get; set; }

    public DateTime? ProcessedAt { get; set; }

    public string? FailureReason { get; set; }
}
