using System.Globalization;

namespace Gostio.API.Hubs;

internal static class ChatGroups
{
    // The hub joins a connection to this and the broadcast sends to it, so the
    // two must spell it the same way or a message is delivered to nobody.
    public static string Of(int conversationId) =>
        "conversation-" + conversationId.ToString(CultureInfo.InvariantCulture);

    // Every connection an account holds, joined at the handshake. A thread it
    // is not reading still has to reach its inbox and its badge.
    public static string ForAccount(int userId) =>
        "account-" + userId.ToString(CultureInfo.InvariantCulture);
}
