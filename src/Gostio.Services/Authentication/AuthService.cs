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

        if (account is null || !PasswordHasher.Verify(request.Password, account.PasswordHash))
        {
            throw new UnauthorizedException(CredentialsRejected);
        }

        // Checked after the password and not before it: an answer that tells a
        // deactivated account apart from an unknown one only helps somebody who
        // already knows the password.
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

        await db.Users
            .Where(user => user.Id == account.Id)
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(user => user.PasswordHash, hash)
                    .SetProperty(user => user.TokenVersion, user => user.TokenVersion + 1)
                    .SetProperty(user => user.ModifiedAt, changedAt),
                cancellationToken);

        // Every token issued before the change is stale now, this caller's
        // included, so the reply carries the one that replaces it.
        return Issue(account, account.TokenVersion + 1);
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
