namespace Gostio.Model.Responses;

public sealed class CountryResponse : IIdentified
{
    public required int Id { get; init; }

    public required string Name { get; init; }

    public required string IsoCode { get; init; }
}
