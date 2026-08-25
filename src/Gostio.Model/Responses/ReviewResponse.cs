namespace Gostio.Model.Responses;

public sealed class ReviewResponse : IIdentified
{
    public required int Id { get; init; }

    public required int ReservationId { get; init; }

    public required int GuestId { get; init; }

    public required string GuestName { get; init; }

    public int? AccommodationId { get; init; }

    public int? ExperienceId { get; init; }

    public required string ListingTitle { get; init; }

    public required int Rating { get; init; }

    public string? Comment { get; init; }

    public required DateTime CreatedAt { get; init; }

    public DateTime? ModifiedAt { get; init; }
}
