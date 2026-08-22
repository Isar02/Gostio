namespace Gostio.Services.Authentication;

// A valid signature proves who signed in, not that the session is still open.
// Signing out and deactivating an account both have to bite before the token
// expires, so every authenticated request checks the version it carries.
public interface IUserSessionValidator
{
    Task<bool> IsCurrentAsync(int userId, int tokenVersion, CancellationToken cancellationToken);
}
