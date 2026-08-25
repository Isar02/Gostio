using Gostio.Model.Exceptions;
using Gostio.Model.Messaging;
using Gostio.Model.Requests;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class PasswordResetTests(DatabaseFixture fixture)
{
    private const string OldPassword = "the-old-password";

    private const string NewPassword = "the-new-password";

    [Fact]
    public async Task AskingForALinkLeavesOneUnusedTokenWithAnExpiry()
    {
        var userId = await fixture.AddUserAsync(OldPassword);

        await ForgotAsync(await EmailOfAsync(userId));

        await using var db = fixture.CreateContext();

        var token = await db.PasswordResetTokens.SingleAsync(row => row.UserId == userId);

        Assert.Null(token.UsedAt);
        Assert.True(token.ExpiresAt > DateTime.UtcNow);
        Assert.Equal(token.CreatedAt + ResetTokens.Lifetime, token.ExpiresAt);
    }

    [Fact]
    public async Task AnAddressNoAccountHasIsAnsweredAndWritesNothing()
    {
        var before = await TokenCountAsync();

        var notices = await ForgotAsync("nobody@example.com");

        Assert.Equal(before, await TokenCountAsync());
        Assert.Empty(notices.Sent);
    }

    // The row keeps only a hash, so the code in the mail is the one road back
    // to the account. A mail that never went is a reset nobody can finish.
    [Fact]
    public async Task TheCodeLeavesByMailAndTheMailIsWhatCarriesIt()
    {
        var userId = await fixture.AddUserAsync(OldPassword);
        var address = await EmailOfAsync(userId);

        var notices = await ForgotAsync(address);
        var mail = Assert.Single(notices.Of<EmailMessage>());

        Assert.Equal(address, mail.ToEmail);

        await using var db = fixture.CreateContext();

        var stored = await db.PasswordResetTokens.SingleAsync(row => row.UserId == userId);
        var code = CodeIn(mail.Body);

        Assert.Equal(stored.TokenHash, ResetTokens.Hash(code));
        Assert.DoesNotContain(stored.TokenHash, mail.Body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task TheCodeInTheMailIsTheOneThatChangesThePassword()
    {
        var userId = await fixture.AddUserAsync(OldPassword);

        var notices = await ForgotAsync(await EmailOfAsync(userId));

        await ResetAsync(CodeIn(Assert.Single(notices.Of<EmailMessage>()).Body), NewPassword);

        Assert.True(PasswordHasher.Verify(NewPassword, await PasswordHashOfAsync(userId)));
    }

    [Fact]
    public async Task SpendingATokenWritesTheNewPasswordAndEndsEverySession()
    {
        var userId = await fixture.AddUserAsync(OldPassword);
        var version = await VersionOfAsync(userId);
        var token = await IssueAsync(userId, DateTime.UtcNow);

        await ResetAsync(token, NewPassword);

        await using var db = fixture.CreateContext();

        var user = await db.Users.SingleAsync(row => row.Id == userId);
        var spent = await db.PasswordResetTokens.SingleAsync(row => row.UserId == userId);

        Assert.True(PasswordHasher.Verify(NewPassword, user.PasswordHash));
        Assert.False(PasswordHasher.Verify(OldPassword, user.PasswordHash));
        Assert.Equal(version + 1, user.TokenVersion);
        Assert.NotNull(spent.UsedAt);
    }

    [Fact]
    public async Task TheSameTokenIsRefusedTheSecondTime()
    {
        var userId = await fixture.AddUserAsync(OldPassword);
        var token = await IssueAsync(userId, DateTime.UtcNow);

        await ResetAsync(token, NewPassword);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => ResetAsync(token, "a-third-password"));

        Assert.Contains(nameof(ResetPasswordRequest.Token), refused.Errors.Keys);
        Assert.True(PasswordHasher.Verify(NewPassword, await PasswordHashOfAsync(userId)));
    }

    [Fact]
    public async Task AnExpiredTokenIsRefusedAndStaysUnspent()
    {
        var userId = await fixture.AddUserAsync(OldPassword);
        var expired = DateTime.UtcNow - ResetTokens.Lifetime - TimeSpan.FromHours(1);
        var token = await IssueAsync(userId, expired);

        await Assert.ThrowsAsync<ValidationException>(() => ResetAsync(token, NewPassword));

        await using var db = fixture.CreateContext();

        var row = await db.PasswordResetTokens.SingleAsync(candidate => candidate.UserId == userId);

        Assert.Null(row.UsedAt);
        Assert.True(PasswordHasher.Verify(OldPassword, await PasswordHashOfAsync(userId)));
    }

    private async Task<CapturedNotices> ForgotAsync(string email)
    {
        var notices = new CapturedNotices();

        await using var db = fixture.CreateContext();

        await Service(db, notices).ForgotPasswordAsync(
            new ForgotPasswordRequest { Email = email }, CancellationToken.None);

        return notices;
    }

    private async Task ResetAsync(string token, string newPassword)
    {
        await using var db = fixture.CreateContext();

        await Service(db).ResetPasswordAsync(
            new ResetPasswordRequest
            {
                Token = token,
                NewPassword = newPassword,
                ConfirmNewPassword = newPassword,
            },
            CancellationToken.None);
    }

    private async Task<string> IssueAsync(int userId, DateTime createdAt)
    {
        await using var db = fixture.CreateContext();

        var token = ResetTokens.Create();

        db.PasswordResetTokens.Add(new PasswordResetToken
        {
            UserId = userId,
            TokenHash = ResetTokens.Hash(token),
            CreatedAt = createdAt,
            ExpiresAt = createdAt + ResetTokens.Lifetime,
        });

        await db.SaveChangesAsync();

        return token;
    }

    private async Task<string> EmailOfAsync(int userId) =>
        await ReadAsync(userId, user => user.Email);

    private async Task<string> PasswordHashOfAsync(int userId) =>
        await ReadAsync(userId, user => user.PasswordHash);

    private async Task<int> VersionOfAsync(int userId) =>
        await ReadAsync(userId, user => user.TokenVersion);

    private async Task<T> ReadAsync<T>(int userId, Func<User, T> read)
    {
        await using var db = fixture.CreateContext();

        return read(await db.Users.SingleAsync(user => user.Id == userId));
    }

    // The body says where to enter it and then states it on a line of its own,
    // which is the only word in the mail as long as a token.
    private static string CodeIn(string body) =>
        body
            .Split(
                ['\r', '\n'],
                StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Single(line => line.Length == ResetTokens.Create().Length);

    private async Task<int> TokenCountAsync()
    {
        await using var db = fixture.CreateContext();

        return await db.PasswordResetTokens.CountAsync();
    }

    private AuthService Service(GostioDbContext db, CapturedNotices? notices = null) =>
        new(
            db,
            new JwtTokenService(fixture.Jwt),
            new AnonymousUser(),
            notices ?? new CapturedNotices(),
            fixture.Api);
}
