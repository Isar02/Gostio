namespace Gostio.Services.Database.Entities;

public class User
{
    public int Id { get; set; }

    public string FirstName { get; set; } = null!;

    public string LastName { get; set; } = null!;

    public string Username { get; set; } = null!;

    public string Email { get; set; } = null!;

    public string? PhoneNumber { get; set; }

    // BCrypt; the salt is part of the hash, so it needs no column of its own.
    public string PasswordHash { get; set; } = null!;

    public byte[]? ProfileImage { get; set; }

    // Cleared instead of deleting the row, so reservations and reviews keep
    // pointing at a real user.
    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; }

    public DateTime? ModifiedAt { get; set; }

    public ICollection<UserRole> UserRoles { get; set; } = [];

    public ICollection<HostVerificationRequest> HostVerificationRequests { get; set; } = [];

    public ICollection<Accommodation> Accommodations { get; set; } = [];

    public ICollection<Experience> Experiences { get; set; } = [];
}
