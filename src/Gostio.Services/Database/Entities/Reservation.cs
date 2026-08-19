namespace Gostio.Services.Database.Entities;

// One table for both bookable things, so payments, refunds, reviews and
// conversations attach to a single ReservationId instead of each repeating a
// nullable pair. A check constraint requires exactly one subject.
public class Reservation
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public User User { get; set; } = null!;

    public int? AccommodationId { get; set; }

    public Accommodation? Accommodation { get; set; }

    // The term, not the experience: a guest books a concrete slot, and the slot
    // already carries the start time, the duration and the capacity.
    public int? ExperienceSlotId { get; set; }

    public ExperienceSlot? ExperienceSlot { get; set; }

    // Both set for a stay, both null for an experience, which reads its dates
    // off the slot. Check-out is the departure day, so it is not slept in.
    public DateOnly? CheckInDate { get; set; }

    public DateOnly? CheckOutDate { get; set; }

    // Required on both sides: it prices an experience and is checked against
    // Accommodation.MaxGuests for a stay.
    public int GuestCount { get; set; }

    public int ReservationStatusId { get; set; }

    public ReservationStatus ReservationStatus { get; set; } = null!;

    // The payment deadline. It decides anything only while the reservation is
    // pending, but it is never null, so a pending row cannot be missing the
    // value ReservationQueries.IsActive reads.
    public DateTime ExpiresAt { get; set; }

    // What was charged. A host may edit a price afterwards, so without these the
    // invoice of a past guest would be rewritten. There is deliberately no
    // nightly rate: AccommodationAvailability.PriceOverride lets the nights of
    // one stay cost different amounts, so a single rate would be a wrong number
    // rather than a missing one, and the nightly total says the truth instead.
    public decimal? AccommodationTotal { get; set; }

    public decimal? CleaningFee { get; set; }

    public decimal? PricePerPerson { get; set; }

    public decimal TotalPrice { get; set; }

    public DateTime CreatedAt { get; set; }

    // No ModifiedAt: everything that happens to a reservation is a status
    // change, and those are rows here.
    public ICollection<ReservationStatusHistory> StatusHistory { get; set; } = [];
}
