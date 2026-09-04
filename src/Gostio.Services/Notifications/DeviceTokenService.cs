using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Validation;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Notifications;

// Both calls are the caller's own and neither takes an account id: whose
// notices reach a device is decided by who registered it, never by a path.
internal sealed class DeviceTokenService(
    GostioDbContext db,
    ICurrentUser currentUser,
    TimeProvider clock) : IDeviceTokenService
{
    public async Task RegisterAsync(
        DeviceTokenRequest request,
        CancellationToken cancellationToken)
    {
        var userId = currentUser.RequireUserId();
        var token = RequiredToken(request);
        var platform = RequiredPlatform(request);
        var now = clock.GetUtcNow().UtcDateTime;

        if (await ClaimAsync(token, userId, platform, now, cancellationToken))
        {
            return;
        }

        var device = db.DeviceTokens.Add(new DeviceToken
        {
            UserId = userId,
            Token = token,
            Platform = platform,
            CreatedAt = now,
            ConfirmedAt = now,
        });

        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException failure) when (DatabaseFailures.IsDuplicate(failure))
        {
            // Another call registered the same device between the two
            // statements above, and the answer to both of them is the same one.
            device.State = EntityState.Detached;

            await ClaimAsync(token, userId, platform, now, cancellationToken);
        }
    }

    public async Task ForgetAsync(DeviceTokenRequest request, CancellationToken cancellationToken)
    {
        var userId = currentUser.RequireUserId();
        var token = RequiredToken(request);

        await db.DeviceTokens
            .Where(device => device.UserId == userId && device.Token == token)
            .ExecuteDeleteAsync(cancellationToken);
    }

    // A device belongs to one account at a time: registering a token somebody
    // else holds moves it rather than adding a second row, so a phone that
    // changed hands cannot still be reached with the last account's notices.
    private async Task<bool> ClaimAsync(
        string token,
        int userId,
        DevicePlatform platform,
        DateTime now,
        CancellationToken cancellationToken) =>
        await db.DeviceTokens
            .Where(device => device.Token == token)
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(device => device.UserId, userId)
                    .SetProperty(device => device.Platform, platform)
                    .SetProperty(device => device.ConfirmedAt, now),
                cancellationToken) > 0;

    private static string RequiredToken(DeviceTokenRequest request)
    {
        var token = request.Token?.Trim();

        if (string.IsNullOrEmpty(token))
        {
            throw new ValidationException(
                nameof(request.Token), "Say which device this registration is for.");
        }

        if (token.Length > ColumnLengths.DeviceToken)
        {
            throw new ValidationException(
                nameof(request.Token),
                $"A device token is at most {ColumnLengths.DeviceToken} characters.");
        }

        return token;
    }

    private static DevicePlatform RequiredPlatform(DeviceTokenRequest request)
    {
        var platform = request.Platform ?? throw new ValidationException(
            nameof(request.Platform), "Say which platform the device runs.");

        if (!Enum.IsDefined(platform))
        {
            throw new ValidationException(
                nameof(request.Platform), "This is not a platform the application knows.");
        }

        return platform;
    }
}
