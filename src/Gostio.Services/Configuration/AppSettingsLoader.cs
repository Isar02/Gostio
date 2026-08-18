using DotNetEnv;
using Microsoft.Data.SqlClient;

namespace Gostio.Services.Configuration;

// The only place that reads environment variables: the .env file locally, the
// container environment in Docker.
public static class AppSettingsLoader
{
    private const string EnvFileName = ".env";
    private const int MaximumParentDirectoriesSearched = 8;
    private const int MinimumJwtKeyLengthInBytes = 32;

    // Throws when a value the application cannot start without is missing, so a
    // half-configured service never boots.
    public static AppSettings Load()
    {
        LoadEnvFileIfPresent();

        var settings = new AppSettings
        {
            Api = new ApiSettings
            {
                BaseUrl = RequireValue("API_BASE_URL"),
                HttpPort = RequireInteger("API_HTTP_PORT")
            },
            Database = new DatabaseSettings
            {
                ConnectionString = ResolveConnectionString(),
                Name = RequireValue("DB_NAME")
            },
            Jwt = new JwtSettings
            {
                Key = RequireValue("JWT_KEY"),
                Issuer = RequireValue("JWT_ISSUER"),
                Audience = RequireValue("JWT_AUDIENCE"),
                ExpiresMinutes = RequireInteger("JWT_EXPIRES_MINUTES")
            },
            RabbitMq = new RabbitMqSettings
            {
                Host = RequireValue("RABBITMQ_HOST"),
                Port = RequireInteger("RABBITMQ_PORT"),
                Username = RequireValue("RABBITMQ_USERNAME"),
                Password = RequireValue("RABBITMQ_PASSWORD"),
                VirtualHost = OptionalValue("RABBITMQ_VIRTUAL_HOST", "/"),
                EmailQueue = RequireValue("RABBITMQ_QUEUE_EMAIL"),
                NotificationQueue = RequireValue("RABBITMQ_QUEUE_NOTIFICATIONS")
            },
            Smtp = new SmtpSettings
            {
                Host = OptionalValue("SMTP_HOST"),
                Port = OptionalInteger("SMTP_PORT", 587),
                Username = OptionalValue("SMTP_USERNAME"),
                Password = OptionalValue("SMTP_PASSWORD"),
                UseSsl = OptionalBoolean("SMTP_USE_SSL", true),
                FromEmail = OptionalValue("SMTP_FROM_EMAIL"),
                FromName = OptionalValue("SMTP_FROM_NAME", "Gostio")
            },
            Stripe = new StripeSettings
            {
                PublishableKey = OptionalValue("STRIPE_PUBLISHABLE_KEY"),
                SecretKey = OptionalValue("STRIPE_SECRET_KEY"),
                WebhookSecret = OptionalValue("STRIPE_WEBHOOK_SECRET"),
                Currency = OptionalValue("STRIPE_CURRENCY", "eur")
            },
            Seed = new SeedSettings
            {
                DefaultPassword = RequireValue("SEED_DEFAULT_PASSWORD")
            },
            CorsAllowedOrigins = ReadCorsAllowedOrigins()
        };

        ValidateJwtKeyStrength(settings.Jwt.Key);

        return settings;
    }

    // Walks up from the current directory, so the application can be started from
    // the repository root, the project folder or a build output folder.
    private static void LoadEnvFileIfPresent()
    {
        var directory = new DirectoryInfo(Directory.GetCurrentDirectory());

        for (var depth = 0; depth < MaximumParentDirectoriesSearched && directory is not null; depth++)
        {
            var candidate = Path.Combine(directory.FullName, EnvFileName);

            if (File.Exists(candidate))
            {
                Env.Load(candidate);
                return;
            }

            directory = directory.Parent;
        }

        // No .env file: the normal case inside a container.
    }

    // A ready-made DATABASE_CONNECTION_STRING wins when present, which is how
    // compose points the containers at the database service name instead of localhost.
    private static string ResolveConnectionString()
    {
        var explicitConnectionString = OptionalValue("DATABASE_CONNECTION_STRING");

        if (!string.IsNullOrWhiteSpace(explicitConnectionString))
        {
            return explicitConnectionString;
        }

        // A builder rather than concatenation, so a password containing separators is escaped.
        var builder = new SqlConnectionStringBuilder
        {
            DataSource = $"{RequireValue("DB_HOST")},{RequireInteger("DB_PORT")}",
            InitialCatalog = RequireValue("DB_NAME"),
            UserID = RequireValue("DB_USER"),
            Password = RequireValue("DB_SA_PASSWORD"),
            TrustServerCertificate = true,
            MultipleActiveResultSets = true
        };

        return builder.ConnectionString;
    }

    private static IReadOnlyList<string> ReadCorsAllowedOrigins()
    {
        var raw = OptionalValue("CORS_ALLOWED_ORIGINS");

        return raw
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .ToArray();
    }

    private static void ValidateJwtKeyStrength(string key)
    {
        var keyLengthInBytes = System.Text.Encoding.UTF8.GetByteCount(key);

        if (keyLengthInBytes < MinimumJwtKeyLengthInBytes)
        {
            throw new InvalidOperationException(
                $"JWT_KEY must be at least {MinimumJwtKeyLengthInBytes} bytes long, " +
                $"but the configured value is {keyLengthInBytes} bytes. " +
                "Generate a cryptographically random key and store it in the .env file.");
        }
    }

    private static string RequireValue(string variableName)
    {
        var value = Environment.GetEnvironmentVariable(variableName);

        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException(
                $"Required configuration value '{variableName}' is missing. " +
                "Add it to the .env file (see .env.example for the full list).");
        }

        return value.Trim();
    }

    private static int RequireInteger(string variableName)
    {
        var raw = RequireValue(variableName);

        if (!int.TryParse(raw, out var value))
        {
            throw new InvalidOperationException(
                $"Configuration value '{variableName}' must be a whole number, but was '{raw}'.");
        }

        return value;
    }

    private static string OptionalValue(string variableName, string defaultValue = "")
    {
        var value = Environment.GetEnvironmentVariable(variableName);

        return string.IsNullOrWhiteSpace(value) ? defaultValue : value.Trim();
    }

    private static int OptionalInteger(string variableName, int defaultValue)
    {
        var raw = OptionalValue(variableName);

        return int.TryParse(raw, out var value) ? value : defaultValue;
    }

    private static bool OptionalBoolean(string variableName, bool defaultValue)
    {
        var raw = OptionalValue(variableName);

        return bool.TryParse(raw, out var value) ? value : defaultValue;
    }
}
