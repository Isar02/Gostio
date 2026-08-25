using Gostio.Model.Enums;

namespace Gostio.Services.HostVerification;

internal sealed record DecisionWords(string Title, string Body);

internal static class HostVerificationNoticeText
{
    public static DecisionWords Of(HostVerificationStatus decision, string? reason) =>
        decision == HostVerificationStatus.Approved
            ? new(
                "You can host on Gostio",
                "Your account was verified. Putting a place or an experience up is yours to do "
                    + "now, and a guest can book it as soon as it is published."
                    + Because(reason))
            : new(
                "Your host verification was turned down",
                "Your account was not verified this time. Applying again is open to you."
                    + Because(reason));

    private static string Because(string? reason) => reason is null ? string.Empty : $" {reason}";
}
