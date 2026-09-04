using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text.Json;
using Gostio.Model.Messaging;
using Gostio.Services.Configuration;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Gostio.Services.Messaging;

// FCM's HTTP v1 API, which authenticates as a service account rather than with
// a key: an assertion signed with the account's private key is exchanged for an
// access token, and that token is held until it is nearly spent.
internal sealed class FirebasePushSender(PushSettings settings) : IPushSender, IDisposable
{
    private const string Scope = "https://www.googleapis.com/auth/firebase.messaging";

    private static readonly TimeSpan AssertionLifetime = TimeSpan.FromHours(1);

    private static readonly TimeSpan RenewedBefore = TimeSpan.FromMinutes(5);

    private static readonly JsonWebTokenHandler Assertions = new();

    private readonly SemaphoreSlim gate = new(1, 1);

    private readonly HttpClient http = new();

    private ServiceAccount? account;

    private string? accessToken;

    private DateTime accessTokenExpiresAt;

    public async Task<PushDelivery> SendAsync(
        string token,
        PushMessage message,
        CancellationToken cancellationToken)
    {
        var credentials = Account();

        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://fcm.googleapis.com/v1/projects/{credentials.ProjectId}/messages:send")
        {
            Content = JsonContent.Create(Envelope(token, message)),
        };

        request.Headers.Authorization = new AuthenticationHeaderValue(
            "Bearer", await AccessTokenAsync(credentials, cancellationToken));

        using var response = await http.SendAsync(request, cancellationToken);

        if (response.IsSuccessStatusCode)
        {
            return PushDelivery.Delivered;
        }

        // A wrong project answers 404 as well, and a registration deleted on
        // that answer is a device nobody can reach again. The service says
        // which of the two this is, and only its own word removes a row.
        var answer = await response.Content.ReadAsStringAsync(cancellationToken);

        if (FcmError.Says(FcmError.Unregistered, answer))
        {
            return PushDelivery.Unregistered;
        }

        // Throws: nothing reaches this but a status that was not a success.
        response.EnsureSuccessStatusCode();

        return PushDelivery.Delivered;
    }

    public void Dispose()
    {
        http.Dispose();
        gate.Dispose();
    }

    // Data values travel as strings, and a tapped notice opens a screen by id
    // inside the running client rather than through a link.
    private static object Envelope(string token, PushMessage message) => new
    {
        message = new
        {
            token,
            notification = new { title = message.Title, body = message.Body },
            data = new Dictionary<string, string>
            {
                ["type"] = ((int)message.Type).ToString(),
                ["reservationId"] = message.ReservationId?.ToString() ?? string.Empty,
            },
        },
    };

    private ServiceAccount Account()
    {
        if (account is ServiceAccount known)
        {
            return known;
        }

        if (!settings.IsConfigured)
        {
            throw new PermanentMessageFailure(
                "Sending a push needs FIREBASE_SERVICE_ACCOUNT_BASE64 in the .env file.");
        }

        account = ServiceAccount.Read(settings.ServiceAccount);

        return account.Value;
    }

    private async Task<string> AccessTokenAsync(
        ServiceAccount credentials,
        CancellationToken cancellationToken)
    {
        await gate.WaitAsync(cancellationToken);

        try
        {
            if (accessToken is string held && DateTime.UtcNow < accessTokenExpiresAt)
            {
                return held;
            }

            var issued = await MintAsync(credentials, cancellationToken);

            accessToken = issued.Token;
            accessTokenExpiresAt = issued.ExpiresAt;

            return issued.Token;
        }
        finally
        {
            gate.Release();
        }
    }

    private async Task<(string Token, DateTime ExpiresAt)> MintAsync(
        ServiceAccount credentials,
        CancellationToken cancellationToken)
    {
        using var content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
            ["assertion"] = AssertionFor(credentials),
        });

        using var response = await http.PostAsync(credentials.TokenUri, content, cancellationToken);

        response.EnsureSuccessStatusCode();

        using var answer = JsonDocument.Parse(
            await response.Content.ReadAsStringAsync(cancellationToken));

        var seconds = answer.RootElement.GetProperty("expires_in").GetInt32();

        return (
            answer.RootElement.GetProperty("access_token").GetString()
                ?? throw new PermanentMessageFailure("The token endpoint answered without one."),
            DateTime.UtcNow.AddSeconds(seconds) - RenewedBefore);
    }

    private static string AssertionFor(ServiceAccount credentials)
    {
        using var key = RSA.Create();

        key.ImportFromPem(credentials.PrivateKey);

        var issuedAt = DateTime.UtcNow;

        return Assertions.CreateToken(new SecurityTokenDescriptor
        {
            Issuer = credentials.ClientEmail,
            Audience = credentials.TokenUri,
            IssuedAt = issuedAt,
            Expires = issuedAt + AssertionLifetime,
            Claims = new Dictionary<string, object> { ["scope"] = Scope },
            SigningCredentials = new SigningCredentials(
                new RsaSecurityKey(key.ExportParameters(true)), SecurityAlgorithms.RsaSha256),
        });
    }

    private readonly record struct ServiceAccount(
        string ProjectId,
        string ClientEmail,
        string PrivateKey,
        string TokenUri)
    {
        public static ServiceAccount Read(string base64)
        {
            try
            {
                using var document = JsonDocument.Parse(Convert.FromBase64String(base64));

                return new ServiceAccount(
                    Text(document, "project_id"),
                    Text(document, "client_email"),
                    Text(document, "private_key"),
                    Text(document, "token_uri"));
            }
            catch (Exception failure)
                when (failure is FormatException or JsonException or KeyNotFoundException)
            {
                throw new PermanentMessageFailure(
                    "FIREBASE_SERVICE_ACCOUNT_BASE64 is not a base64 service account document.");
            }
        }

        private static string Text(JsonDocument document, string field) =>
            document.RootElement.TryGetProperty(field, out var value)
                && value.GetString() is string text
                    ? text
                    : throw new KeyNotFoundException(field);
    }
}
