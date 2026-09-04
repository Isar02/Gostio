using Gostio.Model.Enums;

namespace Gostio.Services.Database.Entities;

public class DeviceToken
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public User User { get; set; } = null!;

    public string Token { get; set; } = null!;

    public DevicePlatform Platform { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime ConfirmedAt { get; set; }
}
