namespace Gostio.Services.Database.Entities;

public class UserRole
{
    public int UserId { get; set; }

    public User User { get; set; } = null!;

    public int RoleId { get; set; }

    public Role Role { get; set; } = null!;

    public DateTime AssignedAt { get; set; }
}
