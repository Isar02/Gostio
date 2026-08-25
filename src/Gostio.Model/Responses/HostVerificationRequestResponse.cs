namespace Gostio.Model.Responses;

public sealed class HostVerificationRequestResponse : IIdentified
{
    public required int Id { get; init; }

    public required int UserId { get; init; }

    public required string Username { get; init; }

    public required string ApplicantName { get; init; }

    public required string Status { get; init; }

    public required DateTime SubmittedAt { get; init; }

    public int? ReviewedByUserId { get; init; }

    public string? ReviewedByName { get; init; }

    public DateTime? ReviewedAt { get; init; }

    public string? DecisionReason { get; init; }
}
