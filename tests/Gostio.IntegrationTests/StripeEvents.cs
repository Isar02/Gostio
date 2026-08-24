using System.Security.Cryptography;
using System.Text;
using Stripe;

namespace Gostio.IntegrationTests;

// Builds what Stripe posts and signs it the way Stripe signs it: an HMAC over
// the timestamp and the exact bytes of the body. Nothing here reaches into the
// application, so a test that passes verification proves the real header shape.
internal static class StripeEvents
{
    public static string Payload(string type, string intentId, string? declineMessage = null)
    {
        var error = declineMessage is null
            ? string.Empty
            : $$""" , "last_payment_error": { "message": "{{declineMessage}}" } """;

        return $$"""
            {
              "id": "evt_{{Guid.NewGuid():N}}",
              "object": "event",
              "api_version": "{{StripeConfiguration.ApiVersion}}",
              "type": "{{type}}",
              "data": {
                "object": { "id": "{{intentId}}", "object": "payment_intent"{{error}} }
              }
            }
            """;
    }

    public static string SignatureFor(string payload, string secret)
    {
        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds();

        var digest = HMACSHA256.HashData(
            Encoding.UTF8.GetBytes(secret),
            Encoding.UTF8.GetBytes($"{timestamp}.{payload}"));

        return $"t={timestamp},v1={Convert.ToHexStringLower(digest)}";
    }
}
