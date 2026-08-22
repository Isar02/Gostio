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
}
