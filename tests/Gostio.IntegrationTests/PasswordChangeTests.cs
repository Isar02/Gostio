using System.Globalization;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.JsonWebTokens;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class PasswordChangeTests(DatabaseFixture fixture)
{
    // The two calls set the password to the one already in use, so whichever
    // of them reads the row second still meets a hash its request verifies
    // against, and the versions are the only thing the ordering decides.
    private const string Password = "the-password-in-use";

    [Fact]
    public async Task TheTokenCarriesTheVersionTheRowEndsWith()
    {
        var userId = await fixture.AddUserAsync(Password);

        var response = await ChangeAsync(userId);

        Assert.Equal(await VersionOnTheRowAsync(userId), VersionIn(response));
    }

    [Fact]
    public async Task TwoChangesAtOnceAreHandedTwoDifferentVersions()
    {
        var userId = await fixture.AddUserAsync(Password);
        var before = await VersionOnTheRowAsync(userId);

        var responses = await Task.WhenAll(ChangeAsync(userId), ChangeAsync(userId));

        var handedOut = responses.Select(VersionIn).Order().ToArray();

        Assert.Equal([before + 1, before + 2], handedOut);
        Assert.Equal(before + 2, await VersionOnTheRowAsync(userId));
    }

    private async Task<AuthResponse> ChangeAsync(int userId)
    {
        await using var db = fixture.CreateContext();

        var auth = new AuthService(
            db, new JwtTokenService(fixture.Jwt), new SignedInUser(userId));

        return await auth.ChangePasswordAsync(
            new ChangePasswordRequest
            {
                CurrentPassword = Password,
                NewPassword = Password,
                ConfirmNewPassword = Password,
            },
            CancellationToken.None);
    }

    private async Task<int> VersionOnTheRowAsync(int userId)
    {
        await using var db = fixture.CreateContext();

        return await db.Users
            .Where(user => user.Id == userId)
            .Select(user => user.TokenVersion)
            .SingleAsync();
    }

    private static int VersionIn(AuthResponse response) =>
        int.Parse(
            new JsonWebToken(response.Token).GetClaim(GostioClaimTypes.TokenVersion).Value,
            CultureInfo.InvariantCulture);
}
