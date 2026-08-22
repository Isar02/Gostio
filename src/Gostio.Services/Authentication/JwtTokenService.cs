using System.Text;
using Gostio.Model.Authorization;
using Gostio.Services.Configuration;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Gostio.Services.Authentication;

public sealed class JwtTokenService(JwtSettings settings)
{
    public const string SigningAlgorithm = SecurityAlgorithms.HmacSha256;

    private static readonly JsonWebTokenHandler Handler = new();

    private readonly SigningCredentials credentials = new(
        new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.Key)),
        SigningAlgorithm);

    public IssuedToken Issue(TokenSubject subject)
    {
        var issuedAt = DateTime.UtcNow;
        var expiresAt = issuedAt.AddMinutes(settings.ExpiresMinutes);

        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = settings.Issuer,
            Audience = settings.Audience,
            IssuedAt = issuedAt,
            NotBefore = issuedAt,
            Expires = expiresAt,
            SigningCredentials = credentials,
            Claims = new Dictionary<string, object>
            {
                [GostioClaimTypes.UserId] = subject.UserId,
                [GostioClaimTypes.Username] = subject.Username,
                [GostioClaimTypes.Email] = subject.Email,
                [GostioClaimTypes.TokenVersion] = subject.TokenVersion,
                [GostioClaimTypes.Role] = subject.Roles.ToArray(),
            },
        };

        return new IssuedToken(Handler.CreateToken(descriptor), expiresAt);
    }
}
