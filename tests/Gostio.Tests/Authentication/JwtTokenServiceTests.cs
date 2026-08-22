using Gostio.Model.Authorization;
using Gostio.Services.Authentication;
using Gostio.Services.Configuration;
using Microsoft.IdentityModel.JsonWebTokens;

namespace Gostio.Tests.Authentication;

public class JwtTokenServiceTests
{
    private const int LifetimeInMinutes = 30;

    private static readonly TokenSubject Subject = new(
        42,
        "administrator",
        "administrator@example.com",
        3,
        [RoleNames.Administrator, RoleNames.Host]);

    [Fact]
    public void ATokenCarriesEveryClaimTheServerReadsBack()
    {
        var token = new JsonWebToken(Issue().Value);

        Assert.Equal("42", token.GetClaim(GostioClaimTypes.UserId).Value);
        Assert.Equal("administrator", token.GetClaim(GostioClaimTypes.Username).Value);
        Assert.Equal("administrator@example.com", token.GetClaim(GostioClaimTypes.Email).Value);
        Assert.Equal("3", token.GetClaim(GostioClaimTypes.TokenVersion).Value);

        Assert.Equal(
            [RoleNames.Administrator, RoleNames.Host],
            token.Claims
                .Where(claim => claim.Type == GostioClaimTypes.Role)
                .Select(claim => claim.Value)
                .ToArray());
    }

    // A reply that promises one expiry while the token states another sends the
    // clients to renew at the wrong moment.
    [Fact]
    public void TheExpiryInTheReplyIsTheExpiryInTheToken()
    {
        var issued = Issue();

        Assert.Equal(
            issued.ExpiresAt.ToString("s"),
            new JsonWebToken(issued.Value).ValidTo.ToString("s"));

        var expected = DateTime.UtcNow.AddMinutes(LifetimeInMinutes);

        Assert.InRange(issued.ExpiresAt, expected.AddMinutes(-1), expected.AddMinutes(1));
    }

    [Fact]
    public void TheTokenIsSignedRatherThanMerelyEncoded()
    {
        var token = new JsonWebToken(Issue().Value);

        Assert.Equal("HS256", token.Alg);
        Assert.False(string.IsNullOrEmpty(token.EncodedSignature));
    }

    private static IssuedToken Issue() =>
        new JwtTokenService(new JwtSettings
        {
            Key = "a-signing-key-long-enough-for-hmac-sha256",
            Issuer = "Gostio.Tests",
            Audience = "Gostio.Tests.Clients",
            ExpiresMinutes = LifetimeInMinutes,
        }).Issue(Subject);
}
