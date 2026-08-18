using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Configuration;

public static class ConfigurationServiceCollectionExtensions
{
    // Returns the settings so the caller can use them while still building the
    // application, for example when configuring JWT authentication.
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
