namespace Gostio.Services.Authentication;

// A signature proves who signed in, not that the session is still open, so
// every authenticated request checks the version the token carries.
public interface IUserSessionValidator
{
    Task<bool> IsCurrentAsync(int userId, int tokenVersion, CancellationToken cancellationToken);
}
