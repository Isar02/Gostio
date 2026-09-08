namespace Gostio.Services.Authentication;

// A signature proves who signed in, not that the session is still open, so
// every authenticated request checks the version the token carries.
public interface IUserSessionValidator
{
    Task<bool> IsCurrentAsync(int userId, int tokenVersion, CancellationToken cancellationToken);

    // The same question about several sessions at once, so a delivery holding a
    // handful of sockets reads once. Closed accounts answer with nothing.
    Task<IReadOnlyDictionary<int, int>> CurrentVersionsAsync(
        IReadOnlyCollection<int> userIds,
        CancellationToken cancellationToken);
}
