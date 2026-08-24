namespace Gostio.Model.Responses;

public sealed class ReservationResponse : IIdentified
{
    public required int Id { get; init; }

    public required int UserId { get; init; }

    public int? AccommodationId { get; init; }

    public int? ExperienceSlotId { get; init; }

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

    public required DateTime CreatedAt { get; init; }
}
