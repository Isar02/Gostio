using Gostio.Model.Enums;

namespace Gostio.Services.Search;

public sealed record SearchSignal
{
    public required SearchTarget Target { get; init; }

    public string? Term { get; init; }

    public int? CityId { get; init; }

    public int? GuestCount { get; init; }

    public decimal? MinPrice { get; init; }

    public decimal? MaxPrice { get; init; }
}
