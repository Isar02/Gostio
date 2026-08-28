using System.Linq.Expressions;
using Gostio.Model.Responses;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Authentication;

// The columns authentication needs and no others: reading the row itself would
// carry the profile image through every sign in and every look at the account.
internal sealed record UserAccount
{
    public static readonly Expression<Func<User, UserAccount>> Projection =
        user => new UserAccount
        {
            Id = user.Id,
            FirstName = user.FirstName,
            LastName = user.LastName,
            Username = user.Username,
            Email = user.Email,
            PhoneNumber = user.PhoneNumber,
            HasProfileImage = user.ProfileImage != null,
            PasswordHash = user.PasswordHash,
            IsActive = user.IsActive,
            TokenVersion = user.TokenVersion,
            CreatedAt = user.CreatedAt,
            Roles = user.UserRoles.Select(assignment => assignment.Role.Name).ToList(),
        };

    public required int Id { get; init; }

    public required string FirstName { get; init; }

    public required string LastName { get; init; }

    public required string Username { get; init; }

    public required string Email { get; init; }

    public required string? PhoneNumber { get; init; }

    public required bool HasProfileImage { get; init; }

    public required string PasswordHash { get; init; }

    public required bool IsActive { get; init; }

    public required int TokenVersion { get; init; }

    public required DateTime CreatedAt { get; init; }

    public required List<string> Roles { get; init; }

    public TokenSubject AsTokenSubject() =>
        new(Id, Username, Email, TokenVersion, Roles);

    public UserResponse ToResponse() =>
        new()
        {
            Id = Id,
            FirstName = FirstName,
            LastName = LastName,
            Username = Username,
            Email = Email,
            PhoneNumber = PhoneNumber,
            HasProfileImage = HasProfileImage,
            IsActive = IsActive,
            Roles = Roles,
            CreatedAt = CreatedAt,
        };
}
