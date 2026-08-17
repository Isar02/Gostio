using Gostio.Model.Enums;

namespace Gostio.Services.Database.Entities;

/// <summary>
/// A guest asking to become a host, and the administrator's decision on it.
/// Kept as its own table rather than a flag on <see cref="User"/> so the reason
/// behind a rejection survives a later re-application.
/// </summary>
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

    /// <summary>Shown to the applicant, so a rejection is never unexplained.</summary>
    public string? DecisionReason { get; set; }
}
