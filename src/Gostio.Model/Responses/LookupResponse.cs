namespace Gostio.Model.Responses;

public sealed class LookupResponse : IIdentified
{
    public required int Id { get; init; }

    public required string Name { get; init; }
}
