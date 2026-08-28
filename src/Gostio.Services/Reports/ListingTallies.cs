namespace Gostio.Services.Reports;

internal interface IPlacedTally
{
    int CityId { get; }

    int CategoryId { get; }
}

// The published tally carries the names because it is the only one grouped over
// the catalogue itself, and every other key belongs to a listing that is a row
// in it: a listing holding a booking cannot be deleted.
internal sealed record ListingTally(
    int CityId,
    string City,
    int CategoryId,
    string Category,
    int Published) : IPlacedTally;

internal sealed record BookingTally(int CityId, int CategoryId, int Bookings, int UnitsSold)
    : IPlacedTally;

internal sealed record ChargeTally(
    int CityId,
    int CategoryId,
    string Currency,
    decimal GrossCharged) : IPlacedTally;

internal sealed record ReviewTally(int CityId, int CategoryId, int Count, int RatingSum)
    : IPlacedTally;
