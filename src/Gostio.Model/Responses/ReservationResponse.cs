namespace Gostio.Model.Responses;

public sealed class ReservationResponse : IIdentified
{
    public required int Id { get; init; }

    public required int UserId { get; init; }

    public required string GuestName { get; init; }

    public int? AccommodationId { get; init; }

    public int? ExperienceId { get; init; }

    public int? ExperienceSlotId { get; init; }

    // The accommodation's or the experience's, whichever the row names.
    public required string ListingTitle { get; init; }

    public DateOnly? CheckInDate { get; init; }

    public DateOnly? CheckOutDate { get; init; }

    public required int GuestCount { get; init; }

    public required int ReservationStatusId { get; init; }

    public required string Status { get; init; }

    public required DateTime ExpiresAt { get; init; }

    public decimal? AccommodationTotal { get; init; }

    public decimal? CleaningFee { get; init; }

    public decimal? PricePerPerson { get; init; }

    public required decimal TotalPrice { get; init; }

    // A settled charge, never a client's word for one, so a screen hides its pay
    // button on the answer it already has.
    public required bool IsPaid { get; init; }

    public required DateTime CreatedAt { get; init; }
}
