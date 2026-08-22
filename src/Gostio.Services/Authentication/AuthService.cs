using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Authentication;

public sealed class AuthService(
    GostioDbContext db,
    JwtTokenService tokens,
    ICurrentUser currentUser) : IAuthService
{
    private const string CredentialsRejected = "The username or password is incorrect.";

    private const string AccountGone = "The signed in account no longer exists.";

    public async Task<AuthResponse> LoginAsync(
        LoginRequest request,
        CancellationToken cancellationToken)
    {
        var account = await FindByUsernameAsync(request.Username, cancellationToken);

        if (account is null)
        {
            // Not a wasted call: without it an unknown username answers
            // sooner than a wrong password and the clock names the accounts.
            PasswordHasher.VerifyAgainstNothing(request.Password);

            throw new UnauthorizedException(CredentialsRejected);
        }

        if (!PasswordHasher.Verify(request.Password, account.PasswordHash))
        {
            throw new UnauthorizedException(CredentialsRejected);
        }

        // After the password and not before it: telling a deactivated account
        // apart from an unknown one only helps somebody who has the password.
        if (!account.IsActive)
        {
            throw new ForbiddenException(
                "This account has been deactivated. Ask an administrator to reopen it.");
        }

        return Issue(account, account.TokenVersion);
    }

    public async Task<UserResponse> GetCurrentUserAsync(CancellationToken cancellationToken)
    {
        var account = await RequireAccountAsync(cancellationToken);

        return account.ToResponse();
    }

    public async Task<AuthResponse> ChangePasswordAsync(
        ChangePasswordRequest request,
        CancellationToken cancellationToken)
    {
        var account = await RequireAccountAsync(cancellationToken);

        if (!PasswordHasher.Verify(request.CurrentPassword, account.PasswordHash))
        {
            throw new ValidationException(
                nameof(request.CurrentPassword), "This is not your current password.");
        }

        var hash = PasswordHasher.Hash(request.NewPassword);
        DateTime? changedAt = DateTime.UtcNow;

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await db.Users
            .Where(user => user.Id == account.Id)
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(user => user.PasswordHash, hash)
                    .SetProperty(user => user.TokenVersion, user => user.TokenVersion + 1)
                    .SetProperty(user => user.ModifiedAt, changedAt),
                cancellationToken);

        // Read back rather than computed: the update holds the row until this
        // commits, so two callers at once cannot be handed the same version.
        var tokenVersion = await db.Users
            .Where(user => user.Id == account.Id)
            .Select(user => user.TokenVersion)
            .SingleAsync(cancellationToken);

        await transaction.CommitAsync(cancellationToken);

        return Issue(account, tokenVersion);
    }

    public async Task LogoutAsync(CancellationToken cancellationToken)
    {
        var userId = currentUser.RequireUserId();

        await db.Users
            .Where(user => user.Id == userId)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(
                    user => user.TokenVersion, user => user.TokenVersion + 1),
                cancellationToken);
    }

    private async Task<UserAccount> RequireAccountAsync(CancellationToken cancellationToken)
    {
        var userId = currentUser.RequireUserId();

        return await FindByIdAsync(userId, cancellationToken)
            ?? throw new NotFoundException(AccountGone);
    }

    private Task<UserAccount?> FindByUsernameAsync(
        string username,
        CancellationToken cancellationToken) =>
        db.Users
            .Where(user => user.Username == username)
            .Select(UserAccount.Projection)
            .FirstOrDefaultAsync(cancellationToken);

    private Task<UserAccount?> FindByIdAsync(int userId, CancellationToken cancellationToken) =>
        db.Users
            .Where(user => user.Id == userId)
            .Select(UserAccount.Projection)
            .FirstOrDefaultAsync(cancellationToken);

    private AuthResponse Issue(UserAccount account, int tokenVersion)
    {
        var token = tokens.Issue(account.AsTokenSubject() with { TokenVersion = tokenVersion });

        return new AuthResponse
        {
            Token = token.Value,
            ExpiresAt = token.ExpiresAt,
            User = account.ToResponse(),
        };
    }
}
