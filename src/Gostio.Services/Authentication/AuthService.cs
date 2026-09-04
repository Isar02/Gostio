using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Messaging;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Authentication;

public sealed class AuthService(
    GostioDbContext db,
    JwtTokenService tokens,
    ICurrentUser currentUser,
    INotices notices) : IAuthService
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

    public async Task<AuthResponse> RegisterAsync(
        RegisterRequest request,
        CancellationToken cancellationToken)
    {
        var account = new NewAccount(request);

        if (await CollisionAsync(account, cancellationToken) is { } taken)
        {
            throw taken;
        }

        var user = account.CreateUser(
            [await GuestRoleIdAsync(cancellationToken)], DateTime.UtcNow);

        db.Users.Add(user);

        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (Exception failure) when (DatabaseFailures.IsDuplicate(failure))
        {
            // The check above lost a race with another registration. Read
            // again, so the answer still names the field rather than the index.
            throw await CollisionAsync(account, cancellationToken) ?? failure;
        }

        var opened = await db.Users
            .Where(candidate => candidate.Id == user.Id)
            .Select(UserAccount.Projection)
            .SingleAsync(cancellationToken);

        return Issue(opened, opened.TokenVersion);
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

    public async Task ForgotPasswordAsync(
        ForgotPasswordRequest request,
        CancellationToken cancellationToken)
    {
        var account = await db.Users
            .Where(user => user.Email == request.Email && user.IsActive)
            .Select(user => new { user.Id, user.FirstName, user.Email })
            .FirstOrDefaultAsync(cancellationToken);

        if (account is null)
        {
            return;
        }

        var issuedAt = DateTime.UtcNow;
        var token = ResetTokens.Create();

        // The row keeps the hash. The token leaves by mail and by no other
        // road: never through a reply, never through the log.
        db.PasswordResetTokens.Add(new PasswordResetToken
        {
            UserId = account.Id,
            TokenHash = ResetTokens.Hash(token),
            CreatedAt = issuedAt,
            ExpiresAt = issuedAt + ResetTokens.Lifetime,
        });

        await db.SaveChangesAsync(cancellationToken);

        await notices.SendAsync(
            PasswordResetEmail.For(account.FirstName, account.Email, token),
            cancellationToken);
    }

    public async Task ResetPasswordAsync(
        ResetPasswordRequest request,
        CancellationToken cancellationToken)
    {
        var tokenHash = ResetTokens.Hash(request.Token);
        var passwordHash = PasswordHasher.Hash(request.NewPassword);
        var usedAt = DateTime.UtcNow;
        DateTime? changedAt = usedAt;

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        var token = await db.PasswordResetTokens
            .Where(candidate => candidate.TokenHash == tokenHash)
            .Select(candidate => new { candidate.Id, candidate.UserId })
            .FirstOrDefaultAsync(cancellationToken);

        // Spending the token is what decides the request, and it is one
        // statement, so two requests carrying it cannot both get past here.
        if (token is null || await SpendAsync(token.Id, usedAt, cancellationToken) != 1)
        {
            throw new ValidationException(
                nameof(request.Token), "This code is no longer valid. Ask for a new one.");
        }

        await db.Users
            .Where(user => user.Id == token.UserId)
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(user => user.PasswordHash, passwordHash)
                    .SetProperty(user => user.TokenVersion, user => user.TokenVersion + 1)
                    .SetProperty(user => user.ModifiedAt, changedAt),
                cancellationToken);

        await transaction.CommitAsync(cancellationToken);
    }

    private Task<int> SpendAsync(int tokenId, DateTime usedAt, CancellationToken cancellationToken) =>
        db.PasswordResetTokens
            .Where(token =>
                token.Id == tokenId && token.UsedAt == null && token.ExpiresAt > usedAt)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(token => token.UsedAt, (DateTime?)usedAt),
                cancellationToken);

    // The comparisons happen in the database, so a username taken under another
    // casing is found under the collation the unique index itself enforces.
    private async Task<ValidationException?> CollisionAsync(
        NewAccount account,
        CancellationToken cancellationToken)
    {
        var username = account.Username;
        var email = account.Email;

        var taken = await db.Users
            .AsNoTracking()
            .Where(user => user.Username == username || user.Email == email)
            .Select(user => new
            {
                Username = user.Username == username,
                Email = user.Email == email,
            })
            .ToListAsync(cancellationToken);

        var errors = new Dictionary<string, string[]>();

        if (taken.Any(row => row.Username))
        {
            errors[nameof(RegisterRequest.Username)] = ["This username is taken."];
        }

        if (taken.Any(row => row.Email))
        {
            errors[nameof(RegisterRequest.Email)] = ["An account already uses this address."];
        }

        return errors.Count == 0 ? null : new ValidationException(errors);
    }

    private Task<int> GuestRoleIdAsync(CancellationToken cancellationToken) =>
        db.Roles
            .Where(role => role.Name == RoleNames.Guest)
            .Select(role => role.Id)
            .SingleAsync(cancellationToken);

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
