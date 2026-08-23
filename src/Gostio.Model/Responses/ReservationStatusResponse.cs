namespace Gostio.Model.Responses;

public sealed class ReservationStatusResponse : IIdentified
{
    public required int Id { get; init; }

    public required string Name { get; init; }

    public required string Code { get; init; }

    public required string? Description { get; init; }
}
