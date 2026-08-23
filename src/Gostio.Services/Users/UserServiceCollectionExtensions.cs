using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Users;

public static class UserServiceCollectionExtensions
{
    public static IServiceCollection AddGostioUserServices(this IServiceCollection services)
    {
        services.AddScoped<IUserService, UserService>();

        return services;
    }
}
