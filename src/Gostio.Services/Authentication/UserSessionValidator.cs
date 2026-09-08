using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Authentication;

public sealed class UserSessionValidator(GostioDbContext db) : IUserSessionValidator
{
    public Task<bool> IsCurrentAsync(
        int userId,
        int tokenVersion,
        CancellationToken cancellationToken) =>
        db.Users.AnyAsync(
            user => user.Id == userId && user.IsActive && user.TokenVersion == tokenVersion,
            cancellationToken);

    public async Task<IReadOnlyDictionary<int, int>> CurrentVersionsAsync(
        IReadOnlyCollection<int> userIds,
        CancellationToken cancellationToken)
    {
        if (userIds.Count == 0)
        {
            return new Dictionary<int, int>();
        }

        var open = await db.Users
            .AsNoTracking()
            .Where(user => user.IsActive && userIds.Contains(user.Id))
            .Select(user => new { user.Id, user.TokenVersion })
            .ToListAsync(cancellationToken);

        return open.ToDictionary(user => user.Id, user => user.TokenVersion);
    }
}
