namespace Gostio.Model.Responses;

// The profile image is absent on purpose: it is a column of bytes, and it is
// served by its own endpoint rather than dragged through every reply. The flag
// beside it is what tells a list whether there is one to fetch at all.
public sealed class UserResponse : IIdentified
{
    public required int Id { get; init; }

    public required string FirstName { get; init; }

    public required string LastName { get; init; }

    public required string Username { get; init; }

    public required string Email { get; init; }

    public required string? PhoneNumber { get; init; }

    public required bool HasProfileImage { get; init; }

    public required bool IsActive { get; init; }

    public required IReadOnlyList<string> Roles { get; init; }

    public required DateTime CreatedAt { get; init; }
}
