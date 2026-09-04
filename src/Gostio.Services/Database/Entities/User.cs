namespace Gostio.Services.Database.Entities;

public class User : IEntity
{
    public int Id { get; set; }

    public string FirstName { get; set; } = null!;

    public string LastName { get; set; } = null!;

    public string Username { get; set; } = null!;

    public string Email { get; set; } = null!;

    public string? PhoneNumber { get; set; }

    public string PasswordHash { get; set; } = null!;

    public byte[]? ProfileImage { get; set; }

    public string? ProfileImageContentType { get; set; }

    public bool IsActive { get; set; } = true;

    // Raised on logout and carried as a claim, so the server refuses tokens
    // issued earlier instead of trusting the client to drop them.
    public int TokenVersion { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime? ModifiedAt { get; set; }

    public ICollection<UserRole> UserRoles { get; set; } = [];

    public ICollection<HostVerificationRequest> HostVerificationRequests { get; set; } = [];

    public ICollection<Accommodation> Accommodations { get; set; } = [];

    public ICollection<Experience> Experiences { get; set; } = [];

    public ICollection<Reservation> Reservations { get; set; } = [];

    public ICollection<Favorite> Favorites { get; set; } = [];

    public ICollection<PasswordResetToken> PasswordResetTokens { get; set; } = [];

    public ICollection<Notification> Notifications { get; set; } = [];

    public ICollection<DeviceToken> DeviceTokens { get; set; } = [];

    public ICollection<SearchHistory> SearchHistory { get; set; } = [];
}
