using Gostio.Model.Enums;

namespace Gostio.Services.Database.Entities;

// Its own table rather than a flag on User, so the reason behind a rejection
// survives a later re-application.
public class HostVerificationRequest
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public User User { get; set; } = null!;

    public HostVerificationStatus Status { get; set; } = HostVerificationStatus.Pending;

    public DateTime SubmittedAt { get; set; }

    public int? ReviewedByUserId { get; set; }

    public User? ReviewedByUser { get; set; }

    public DateTime? ReviewedAt { get; set; }

    public string? DecisionReason { get; set; }
}
