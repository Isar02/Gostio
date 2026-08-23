namespace Gostio.Model.Responses;

// The calendar is open where no row covers it, so what a list of these carries
// is the exceptions rather than the whole year.
public sealed class AccommodationAvailabilityResponse : IIdentified
{
    public required int Id { get; init; }

    public required int AccommodationId { get; init; }

    public required DateOnly StartDate { get; init; }

    public required DateOnly EndDate { get; init; }

    public required bool IsAvailable { get; init; }

    public required decimal? PriceOverride { get; init; }
}
