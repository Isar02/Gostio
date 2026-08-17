namespace Gostio.Services.Database.Entities;

/// <summary>
/// A user holds many roles at once: the same account can host a listing and
/// book somebody else's.
/// </summary>
public class UserRole
{
    public int UserId { get; set; }

    public User User { get; set; } = null!;

    public int RoleId { get; set; }

    public Role Role { get; set; } = null!;

    public DateTime AssignedAt { get; set; }
}
