namespace Gostio.Model.Responses;

public sealed class PaymentResponse : IIdentified
{
    public required int Id { get; init; }

    public required int ReservationId { get; init; }

    public required string Status { get; init; }

    public required decimal Amount { get; init; }

    public required string Currency { get; init; }

    // Both are handed out only to the guest asking to pay, and only while the
    // charge is still open: they are what a card sheet needs to open, and a
    // settled payment has no use for either.
    public string? ClientSecret { get; init; }

    public string? PublishableKey { get; init; }

    public required DateTime CreatedAt { get; init; }

    public DateTime? ProcessedAt { get; init; }

    public string? FailureReason { get; init; }
}
