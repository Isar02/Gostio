using DotNetEnv;
using Gostio.Model.Validation;
using Microsoft.Data.SqlClient;

namespace Gostio.Services.Configuration;

public static class AppSettingsLoader
{
    private const string EnvFileName = ".env";
    private const int MaximumParentDirectoriesSearched = 8;
    private const int MinimumJwtKeyLengthInBytes = 32;
    private const int MaximumPort = 65535;
    private const int MaximumJwtLifetimeInMinutes = 60 * 24 * 30;
    private const int DefaultReservationSweepSeconds = 60;
    private const int MinimumSweepSeconds = 5;
    private const int MaximumSweepSeconds = 60 * 60;
    private const int DefaultReservationSweepBatch = 200;
    private const int MaximumSweepBatch = 1000;
    private const int DefaultRefundSweepSeconds = 120;
    private const int DefaultRefundSweepBatch = 50;
    private const string DefaultCurrency = "eur";
    private const int DefaultLookupCacheSeconds = 600;
    private const int MinimumLookupCacheSeconds = 5;
    private const int MaximumLookupCacheSeconds = 60 * 60 * 24;

    public static AppSettings Load()
    {
        LoadEnvFileIfPresent();

        var settings = new AppSettings
        {
            Api = new ApiSettings
            {
                BaseUrl = RequireValue("API_BASE_URL"),
                HttpPort = RequirePort("API_HTTP_PORT")
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
                ExpiresMinutes = RequireRange(
                    "JWT_EXPIRES_MINUTES",
                    RequireInteger("JWT_EXPIRES_MINUTES"),
                    1,
                    MaximumJwtLifetimeInMinutes)
            },
            RabbitMq = new RabbitMqSettings
            {
                Host = RequireValue("RABBITMQ_HOST"),
                Port = RequirePort("RABBITMQ_PORT"),
                Username = RequireValue("RABBITMQ_USERNAME"),
                Password = RequireValue("RABBITMQ_PASSWORD"),
                VirtualHost = OptionalValue("RABBITMQ_VIRTUAL_HOST", "/"),
                EmailQueue = RequireValue("RABBITMQ_QUEUE_EMAIL"),
                NotificationQueue = RequireValue("RABBITMQ_QUEUE_NOTIFICATIONS")
            },
            Smtp = new SmtpSettings
            {
                Host = OptionalValue("SMTP_HOST"),
                Port = RequireRange("SMTP_PORT", OptionalInteger("SMTP_PORT", 587), 1, MaximumPort),
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
                Currency = RequireSupportedCurrency("STRIPE_CURRENCY")
            },
            Seed = new SeedSettings
            {
                DefaultPassword = RequireValue("SEED_DEFAULT_PASSWORD")
            },
            Worker = new WorkerSettings
            {
                ReservationSweepSeconds = RequireRange(
                    "WORKER_RESERVATION_SWEEP_SECONDS",
                    OptionalInteger(
                        "WORKER_RESERVATION_SWEEP_SECONDS", DefaultReservationSweepSeconds),
                    MinimumSweepSeconds,
                    MaximumSweepSeconds),
                ReservationSweepBatch = RequireRange(
                    "WORKER_RESERVATION_SWEEP_BATCH",
                    OptionalInteger(
                        "WORKER_RESERVATION_SWEEP_BATCH", DefaultReservationSweepBatch),
                    1,
                    MaximumSweepBatch),
                RefundSweepSeconds = RequireRange(
                    "WORKER_REFUND_SWEEP_SECONDS",
                    OptionalInteger("WORKER_REFUND_SWEEP_SECONDS", DefaultRefundSweepSeconds),
                    MinimumSweepSeconds,
                    MaximumSweepSeconds),
                RefundSweepBatch = RequireRange(
                    "WORKER_REFUND_SWEEP_BATCH",
                    OptionalInteger("WORKER_REFUND_SWEEP_BATCH", DefaultRefundSweepBatch),
                    1,
                    MaximumSweepBatch)
            },
            Cache = new CacheSettings
            {
                LookupSeconds = RequireRange(
                    "CACHE_LOOKUP_SECONDS",
                    OptionalInteger("CACHE_LOOKUP_SECONDS", DefaultLookupCacheSeconds),
                    MinimumLookupCacheSeconds,
                    MaximumLookupCacheSeconds)
            },
            CorsAllowedOrigins = ReadCorsAllowedOrigins()
        };

        ValidateJwtKeyStrength(settings.Jwt.Key);

        return settings;
    }

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

    }

    private static string ResolveConnectionString()
    {
        var explicitConnectionString = OptionalValue("DATABASE_CONNECTION_STRING");

        if (!string.IsNullOrWhiteSpace(explicitConnectionString))
        {
            return explicitConnectionString;
        }

        var builder = new SqlConnectionStringBuilder
        {
            DataSource = $"{RequireValue("DB_HOST")},{RequirePort("DB_PORT")}",
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

    // The conversion to minor units assumes two decimal places, so a currency
    // whose exponent is not two would be charged a hundred times wrong without a
    // single failure anywhere. It is refused here, where the value is read.
    private static string RequireSupportedCurrency(string variableName)
    {
        var code = OptionalValue(variableName, DefaultCurrency);

        try
        {
            return Currencies.Normalize(code);
        }
        catch (InvalidOperationException)
        {
            throw new InvalidOperationException(
                $"Configuration value '{variableName}' is '{code}', which this application does "
                    + $"not charge in. It handles {string.Join(", ", Currencies.Supported)}.");
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

    // A default stands in for an absent value, never an unreadable one: a
    // mistyped port that silently becomes 587 is the failure nobody notices.
    private static int OptionalInteger(string variableName, int defaultValue)
    {
        var raw = OptionalValue(variableName);

        if (raw.Length == 0)
        {
            return defaultValue;
        }

        if (!int.TryParse(raw, out var value))
        {
            throw new InvalidOperationException(
                $"Configuration value '{variableName}' must be a whole number, but was '{raw}'.");
        }

        return value;
    }

    private static bool OptionalBoolean(string variableName, bool defaultValue)
    {
        var raw = OptionalValue(variableName);

        if (raw.Length == 0)
        {
            return defaultValue;
        }

        if (!bool.TryParse(raw, out var value))
        {
            throw new InvalidOperationException(
                $"Configuration value '{variableName}' must be true or false, but was '{raw}'.");
        }

        return value;
    }

    private static int RequirePort(string variableName)
    {
        return RequireRange(variableName, RequireInteger(variableName), 1, MaximumPort);
    }

    private static int RequireRange(string variableName, int value, int minimum, int maximum)
    {
        if (value < minimum || value > maximum)
        {
            throw new InvalidOperationException(
                $"Configuration value '{variableName}' must be between {minimum} and {maximum}, "
                + $"but was {value}.");
        }

        return value;
    }
}
