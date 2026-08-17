namespace Gostio.Services.Database.Entities;

public class User
{
    public int Id { get; set; }

    public string FirstName { get; set; } = null!;

    public string LastName { get; set; } = null!;

    public string Username { get; set; } = null!;

    public string Email { get; set; } = null!;

    public string? PhoneNumber { get; set; }

    /// <summary>
    /// BCrypt hash. The salt is part of the hash, so it needs no column of its
    /// own, and the plain password is never stored or logged.
    /// </summary>
    public string PasswordHash { get; set; } = null!;

    public byte[]? ProfileImage { get; set; }

    /// <summary>
    /// Cleared by an administrator instead of deleting the row, so reservations
    /// and reviews keep pointing at a real user.
    /// </summary>
    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; }

    public DateTime? ModifiedAt { get; set; }

    public ICollection<UserRole> UserRoles { get; set; } = [];

    public ICollection<HostVerificationRequest> HostVerificationRequests { get; set; } = [];
}
