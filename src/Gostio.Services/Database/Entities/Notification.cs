using Gostio.Model.Enums;

namespace Gostio.Services.Database.Entities;

public class Notification
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public User User { get; set; } = null!;

    public NotificationType Type { get; set; }

    public int? ReservationId { get; set; }

    public Reservation? Reservation { get; set; }

    public string Title { get; set; } = null!;

    public string Body { get; set; } = null!;

    public DateTime? ReadAt { get; set; }

    public DateTime CreatedAt { get; set; }
}
