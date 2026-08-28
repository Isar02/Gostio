using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class RegistrationTests(DatabaseFixture fixture) : IAsyncLifetime
{
    private const string Password = "a-password-a-visitor-picked";

    public async Task InitializeAsync() => await fixture.EnsureRoleAsync(RoleNames.Guest);

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task ARegistrationOpensAGuestAccountAndSignsItIn()
    {
        var registered = await RegisterAsync(Name());

        Assert.NotEmpty(registered.Token);
        Assert.True(registered.ExpiresAt > DateTime.UtcNow);
        Assert.Equal([RoleNames.Guest], registered.User.Roles);
        Assert.True(registered.User.IsActive);
        Assert.Equal("061 234 567", registered.User.PhoneNumber);

        await using var db = fixture.CreateContext();

        var stored = await db.Users.SingleAsync(user => user.Id == registered.User.Id);

        Assert.True(PasswordHasher.Verify(Password, stored.PasswordHash));
        Assert.Equal(0, stored.TokenVersion);
    }

    [Fact]
    public async Task AUsernameThatIsTakenIsRefusedUnderItsOwnField()
    {
        var taken = Name();

        await RegisterAsync(taken);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => RegisterAsync(taken, $"{Name()}@example.com"));

        Assert.Equal([nameof(RegisterRequest.Username)], refused.Errors.Keys);
    }

    [Fact]
    public async Task AnAddressThatIsTakenIsRefusedUnderItsOwnField()
    {
        var address = $"{Name()}@example.com";

        await RegisterAsync(Name(), address);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => RegisterAsync(Name(), address));

        Assert.Equal([nameof(RegisterRequest.Email)], refused.Errors.Keys);
    }

    // SQL Server compares these under a case-insensitive collation and C# does
    // not, so a check that reads the rows and compares them itself lets this
    // through to the unique index and answers 500 where it owes a 400.
    [Fact]
    public async Task AUsernameTakenUnderAnotherCasingIsStillTaken()
    {
        var taken = Name();

        await RegisterAsync(taken);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => RegisterAsync(taken.ToUpperInvariant(), $"{Name()}@example.com"));

        Assert.Equal([nameof(RegisterRequest.Username)], refused.Errors.Keys);
    }

    [Fact]
    public async Task AnAddressTakenUnderAnotherCasingIsStillTaken()
    {
        var address = $"{Name()}@example.com";

        await RegisterAsync(Name(), address);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => RegisterAsync(Name(), address.ToUpperInvariant()));

        Assert.Equal([nameof(RegisterRequest.Email)], refused.Errors.Keys);
    }

    [Fact]
    public async Task AFormThatCollidesTwiceIsToldAboutBothFieldsAtOnce()
    {
        var username = Name();
        var address = $"{username}@example.com";

        await RegisterAsync(username, address);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => RegisterAsync(username, address));

        Assert.Equal(
            [nameof(RegisterRequest.Email), nameof(RegisterRequest.Username)],
            refused.Errors.Keys.Order());
    }

    // Both callers clear the check before either of them inserts, so the second
    // one meets the unique index instead, and has to answer as the check would.
    [Fact]
    public async Task TwoVisitorsClaimingOneUsernameAtOnceLeaveOneAccount()
    {
        var username = Name();
        var barrier = new CommandBarrier(callers: 2, "INSERT", "[Users]");

        var attempts = await Task.WhenAll(
            AttemptAsync(username, barrier), AttemptAsync(username, barrier));

        Assert.Equal(2, barrier.Arrived);
        Assert.Single(attempts, outcome => outcome is null);

        var refused = Assert.Single(attempts.OfType<ValidationException>());

        Assert.Equal([nameof(RegisterRequest.Username)], refused.Errors.Keys);

        await using var db = fixture.CreateContext();

        Assert.Equal(1, await db.Users.CountAsync(user => user.Username == username));
    }

    private async Task<Exception?> AttemptAsync(
        string username,
        params IInterceptor[] interceptors)
    {
        try
        {
            await RegisterAsync(username, $"{Name()}@example.com", interceptors);

            return null;
        }
        catch (ValidationException refused)
        {
            return refused;
        }
    }

    private async Task<AuthResponse> RegisterAsync(
        string username,
        string? email = null,
        params IInterceptor[] interceptors)
    {
        await using var db = fixture.CreateContext(interceptors);

        var auth = new AuthService(
            db,
            new JwtTokenService(fixture.Jwt),
            new AnonymousUser(),
            new CapturedNotices(),
            fixture.Api);

        return await auth.RegisterAsync(
            new RegisterRequest
            {
                FirstName = "Lejla",
                LastName = "Hodžić",
                Username = username,
                Email = email ?? $"{username}@example.com",
                PhoneNumber = " 061 234 567 ",
                Password = Password,
                ConfirmPassword = Password,
            },
            CancellationToken.None);
    }

    private static string Name() => $"visitor-{Guid.NewGuid():N}";
}
