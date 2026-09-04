using System.Text.Json;

namespace Gostio.Services.Messaging;

// FCM answers 404 both for a registration that is no longer a device and for a
// project that never was one, and deleting a row on the second would leave a
// real phone unreachable for good. The code in the error's details is what
// tells the two apart, so only the service's own word removes anything.
public static class FcmError
{
    public const string Unregistered = "UNREGISTERED";

    // A body that cannot be read is not a device saying it is gone: it falls
    // through to whatever failure the status describes.
    public static bool Says(string errorCode, string body)
    {
        try
        {
            using var answer = JsonDocument.Parse(body);

            return answer.RootElement.TryGetProperty("error", out var error)
                && error.TryGetProperty("details", out var details)
                && details.ValueKind == JsonValueKind.Array
                && details.EnumerateArray().Any(detail =>
                    detail.TryGetProperty("errorCode", out var code)
                    && code.ValueEquals(errorCode));
        }
        catch (JsonException)
        {
            return false;
        }
    }
}
