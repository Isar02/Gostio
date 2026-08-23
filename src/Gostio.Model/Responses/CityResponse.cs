namespace Gostio.Model.Responses;

public sealed class CityResponse : IIdentified
{
    public required int Id { get; init; }

    public required string Name { get; init; }

    public required int CountryId { get; init; }

    public required string CountryName { get; init; }
}
