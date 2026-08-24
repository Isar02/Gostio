namespace Gostio.Model.Responses;

public sealed class RefundQuoteResponse
{
    public required int ReservationId { get; init; }

    // False while nothing has been charged, and the amount below is then what
    // the policy would give back on the price as it stands rather than money.
    public required bool IsPaid { get; init; }

    public required decimal Charged { get; init; }

    public required string Currency { get; init; }

    public required int Percentage { get; init; }

    public required decimal Amount { get; init; }

    public required string Reason { get; init; }

    public required DateTime GraceEndsAt { get; init; }

    // The instant the policy was read against. It moves with the clock while a
    // booking is live and stops at the cancellation once there is one, so an
    // answer given after a booking ended cannot drift away from what was owed.
    public required DateTime AsOf { get; init; }
}
