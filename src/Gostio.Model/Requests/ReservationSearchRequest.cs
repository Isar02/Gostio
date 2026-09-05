namespace Gostio.Model.Requests;

public sealed class ReservationSearchRequest : PagedRequest
{
    public int? GuestId { get; set; }

    public int? HostId { get; set; }

    public int? AccommodationId { get; set; }

    public int? ExperienceId { get; set; }

    public int? ExperienceSlotId { get; set; }

    public int? ReservationStatusId { get; set; }

    // Active here means the booking still holds its place.
    public bool? IsActive { get; set; }

    public DateOnly? From { get; set; }

    public DateOnly? To { get; set; }

    // The other side of From on the same day: bookings with no day left to
    // come. Sending both answers nothing, which is what asking for a booking
    // that is at once ahead and over deserves.
    public DateOnly? EndedBefore { get; set; }

    public DateOnly? ArrivesOn { get; set; }

    public DateOnly? DepartsOn { get; set; }
}
