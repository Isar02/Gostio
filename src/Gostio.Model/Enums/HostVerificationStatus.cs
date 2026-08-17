namespace Gostio.Model.Enums;

/// <summary>
/// Outcome of an administrator's review of a host application. Stored as the
/// underlying integer, so the values are part of the database contract and must
/// not be renumbered.
/// </summary>
public enum HostVerificationStatus
{
    Pending = 1,
    Approved = 2,
    Rejected = 3
}
