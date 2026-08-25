using System.Globalization;

namespace Gostio.API.Hubs;

internal static class ChatGroups
{
    // The hub joins a connection to this and the broadcast sends to it, so the
    // two must spell it the same way or a message is delivered to nobody.
    public static string Of(int conversationId) =>
        "conversation-" + conversationId.ToString(CultureInfo.InvariantCulture);
}
