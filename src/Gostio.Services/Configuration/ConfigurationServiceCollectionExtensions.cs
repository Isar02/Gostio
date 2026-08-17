using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Configuration;

public static class ConfigurationServiceCollectionExtensions
{
    /// <summary>
    /// Loads configuration once at startup and registers it as a singleton.
    /// Every service that needs a configuration value injects
    /// <see cref="AppSettings"/> instead of reading the environment itself,
    /// which keeps environment access in a single place and avoids re-reading
    /// the same variables on every request.
    /// </summary>
    /// <returns>
    /// The loaded settings, so the caller can use them while still building
    /// the application (for example when configuring JWT authentication).
    /// </returns>
    public static AppSettings AddGostioConfiguration(this IServiceCollection services)
    {
        var settings = AppSettingsLoader.Load();

        services.AddSingleton(settings);
        services.AddSingleton(settings.Api);
        services.AddSingleton(settings.Database);
        services.AddSingleton(settings.Jwt);
        services.AddSingleton(settings.RabbitMq);
        services.AddSingleton(settings.Smtp);
        services.AddSingleton(settings.Stripe);
        services.AddSingleton(settings.Seed);

        return settings;
    }
}
