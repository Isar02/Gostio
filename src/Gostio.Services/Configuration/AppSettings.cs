namespace Gostio.Services.Configuration;

/// <summary>
/// Strongly typed view over every configuration value the system uses.
/// Populated exclusively from environment variables (see the .env file) by
/// <see cref="AppSettingsLoader"/>, and registered as a singleton so that no
/// other class ever reads a configuration value on its own.
/// </summary>
public sealed class AppSettings
{
    public required ApiSettings Api { get; init; }
    public required DatabaseSettings Database { get; init; }
    public required JwtSettings Jwt { get; init; }
    public required RabbitMqSettings RabbitMq { get; init; }
    public required SmtpSettings Smtp { get; init; }
    public required StripeSettings Stripe { get; init; }
    public required SeedSettings Seed { get; init; }
    public required IReadOnlyList<string> CorsAllowedOrigins { get; init; }
}

public sealed class ApiSettings
{
    public required string BaseUrl { get; init; }
    public required int HttpPort { get; init; }
}

public sealed class DatabaseSettings
{
    public required string ConnectionString { get; init; }
    public required string Name { get; init; }
}

public sealed class JwtSettings
{
    public required string Key { get; init; }
    public required string Issuer { get; init; }
    public required string Audience { get; init; }
    public required int ExpiresMinutes { get; init; }
}

public sealed class RabbitMqSettings
{
    public required string Host { get; init; }
    public required int Port { get; init; }
    public required string Username { get; init; }
    public required string Password { get; init; }
    public required string VirtualHost { get; init; }
    public required string EmailQueue { get; init; }
    public required string NotificationQueue { get; init; }
}

/// <summary>
/// Used by the worker service to send e-mail. Values may be empty until the
/// mail module is configured; <see cref="IsConfigured"/> reports readiness.
/// </summary>
public sealed class SmtpSettings
{
    public required string Host { get; init; }
    public required int Port { get; init; }
    public required string Username { get; init; }
    public required string Password { get; init; }
    public required bool UseSsl { get; init; }
    public required string FromEmail { get; init; }
    public required string FromName { get; init; }

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(Host) && !string.IsNullOrWhiteSpace(FromEmail);
}

/// <summary>
/// Stripe sandbox credentials. Values may be empty until the payment module is
/// configured; <see cref="IsConfigured"/> reports readiness.
/// </summary>
public sealed class StripeSettings
{
    public required string PublishableKey { get; init; }
    public required string SecretKey { get; init; }
    public required string WebhookSecret { get; init; }
    public required string Currency { get; init; }

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(SecretKey) && !string.IsNullOrWhiteSpace(WebhookSecret);
}

public sealed class SeedSettings
{
    public required string DefaultPassword { get; init; }
}
