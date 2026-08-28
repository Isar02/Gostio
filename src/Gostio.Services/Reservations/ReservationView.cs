namespace Gostio.Services.Reservations;

// A reservation as the gate hands it over: the status the caller is about to
// move, and every fact the move rests on, out of one statement.
internal sealed class ReservationView
{
    public required int StatusId { get; init; }

    public required int GuestId { get; init; }

    public required int HostId { get; init; }

    public int? AccommodationId { get; init; }

    public int? ExperienceId { get; init; }

    public int? ExperienceSlotId { get; init; }

    public DateOnly? CheckInDate { get; init; }

    public DateOnly? CheckOutDate { get; init; }

    public required int GuestCount { get; init; }

    public DateTime? SlotStartTime { get; init; }

    public required DateTime CreatedAt { get; init; }

    public required DateTime ExpiresAt { get; init; }

    public required decimal TotalPrice { get; init; }

    // A stay begins at check-in on the first day it covers, a term at the hour
    // it names.
    public DateTime StartsAt => CheckInDate is { } checkIn
        ? StayTimes.BeginsAt(checkIn)
        : SlotStartTime!.Value;
}
