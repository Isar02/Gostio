using System.Text.Json;

namespace Gostio.Services.Messaging;

public static class MessageJson
{
    public static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);
}
