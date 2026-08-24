namespace Gostio.Model.Responses;

public sealed class RefundResponse : IIdentified
{
    public required int Id { get; init; }

    public required int ReservationId { get; init; }

    public required int PaymentId { get; init; }

    public required string Status { get; init; }

    public required decimal Amount { get; init; }

    public required string Currency { get; init; }

    // Which rule of the cancellation policy decided the amount, which is a
    // different sentence from why the booking was called off.
    public required string Reason { get; init; }

    public required DateTime CreatedAt { get; init; }

    public DateTime? ProcessedAt { get; init; }

    public string? FailureReason { get; init; }
}
