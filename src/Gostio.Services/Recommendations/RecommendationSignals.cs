namespace Gostio.Services.Recommendations;

public enum EngagementKind
{
    Favorite = 1,
    Booking = 2
}

// Carries the axes the listing sits on, read exactly as a candidate's are.
public sealed record EngagedListing(
    int ListingId,
    EngagementKind Kind,
    int? Rating,
    DateTime At,
    decimal Price,
    IReadOnlyList<ListingAxis> Axes);

public sealed record SearchedSignal(
    string? Term,
    int? CityId,
    int? GuestCount,
    decimal? MinPrice,
    decimal? MaxPrice,
    DateTime At);
