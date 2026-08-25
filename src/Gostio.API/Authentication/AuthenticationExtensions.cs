using System.Text;
using Gostio.API.Hubs;
using Gostio.Model.Authorization;
using Gostio.Services.Authentication;
using Gostio.Services.Configuration;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.Tokens;

namespace Gostio.API.Authentication;

public static class AuthenticationExtensions
{
    public static IServiceCollection AddGostioAuthentication(
        this IServiceCollection services,
        JwtSettings jwt)
    {
        services.AddGostioAuthenticationServices();

        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                // Off, so sub stays sub. Mapping renames the claims on the way
                // in to WS-Federation URIs that nothing in this project reads.
                options.MapInboundClaims = false;

                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = jwt.Issuer,
                    ValidateAudience = true,
                    ValidAudience = jwt.Audience,
                    ValidateLifetime = true,
                    // No grace period on top of the expiry the token states.
                    ClockSkew = TimeSpan.Zero,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
                    ValidAlgorithms = [JwtTokenService.SigningAlgorithm],
                    NameClaimType = GostioClaimTypes.Username,
                    RoleClaimType = GostioClaimTypes.Role,
                };

                options.Events = new JwtBearerEvents
                {
                    OnMessageReceived = ReadTheHubTokenFromTheQuery,
                    OnTokenValidated = RejectEndedSessionsAsync,
                };
            });

        services.AddAuthorization(options =>
            options.FallbackPolicy = new AuthorizationPolicyBuilder()
                .RequireAuthenticatedUser()
                .Build());

        return services;
    }

    // A WebSocket handshake carries no headers a client may set, so the SignalR
    // clients send the token as access_token instead. Only this path reads it,
    // so no ordinary endpoint gains a second way of being authenticated.
    private static Task ReadTheHubTokenFromTheQuery(MessageReceivedContext context)
    {
        var token = context.Request.Query["access_token"];

        if (!string.IsNullOrEmpty(token)
            && context.HttpContext.Request.Path.StartsWithSegments(ChatHubRoute.Path))
        {
            context.Token = token;
        }

        return Task.CompletedTask;
    }

    private static async Task RejectEndedSessionsAsync(TokenValidatedContext context)
    {
        var userId = context.Principal?.UserId();
        var tokenVersion = context.Principal?.TokenVersion();

        if (userId is null || tokenVersion is null)
        {
            context.Fail("This token does not say which session it belongs to.");
            return;
        }

        var sessions = context.HttpContext.RequestServices
            .GetRequiredService<IUserSessionValidator>();

        var isCurrent = await sessions.IsCurrentAsync(
            userId.Value, tokenVersion.Value, context.HttpContext.RequestAborted);

        if (!isCurrent)
        {
            context.Fail("The session this token was issued for has ended.");
        }
    }
}
