namespace Gostio.Model.Responses;

public sealed class ExperienceSlotResponse : IIdentified
{
    public required int Id { get; init; }

    public required int ExperienceId { get; init; }

    public required DateTime StartTime { get; init; }

    public required DateTime EndTime { get; init; }

    public required int DurationMinutes { get; init; }

    public required int Capacity { get; init; }

    // Worked out from the reservations holding the slot rather than stored. A
    // second number can disagree with the first, and every disagreement is an
    // overbooking or a seat nobody can buy.
    public required int RemainingCapacity { get; init; }

    public required bool IsActive { get; init; }
}
