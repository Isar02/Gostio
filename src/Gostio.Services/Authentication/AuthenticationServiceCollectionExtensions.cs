using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Authentication;

public static class AuthenticationServiceCollectionExtensions
{
    public static IServiceCollection AddGostioAuthenticationServices(
        this IServiceCollection services)
    {
        services.AddHttpContextAccessor();

        services.AddSingleton<JwtTokenService>();
        services.AddScoped<ICurrentUser, CurrentUser>();
        services.AddScoped<IUserSessionValidator, UserSessionValidator>();
        services.AddScoped<IAuthService, AuthService>();

        return services;
    }
}
