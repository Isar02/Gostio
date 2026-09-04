using Gostio.Model.Messaging;
using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Gostio.Services.Messaging;

internal sealed class PushDispatcher(
    GostioDbContext db,
    IPushSender sender,
    ILogger<PushDispatcher> logger) : IPushDispatcher
{
    public async Task DeliverAsync(PushMessage message, CancellationToken cancellationToken)
    {
        var devices = await db.DeviceTokens
            .AsNoTracking()
            .Where(device => device.UserId == message.UserId)
            .Select(device => device.Token)
            .ToListAsync(cancellationToken);

        var failures = new List<Exception>();

        foreach (var token in devices)
        {
            // One device that cannot be reached is not the others' business:
            // the account may be signed in on a phone and a tablet, and the
            // one behind the failure would otherwise hold up everything after
            // it on this pass and on every retry of it.
            try
            {
                await SendAsync(token, message, cancellationToken);
            }
            catch (Exception failure)
                when (failure is not (OperationCanceledException or PermanentMessageFailure))
            {
                logger.LogWarning(failure, "One device could not be reached.");

                failures.Add(failure);
            }
        }

        // Handed back once the rest have been tried, so the delivery is retried
        // rather than counted as done. A device that already has it may get it
        // twice, which is what a push being a delivery rather than the record
        // allows for.
        if (failures.Count > 0)
        {
            throw new AggregateException(
                $"{failures.Count} of {devices.Count} devices could not be reached.", failures);
        }
    }

    private async Task SendAsync(
        string token,
        PushMessage message,
        CancellationToken cancellationToken)
    {
        var delivery = await sender.SendAsync(token, message, cancellationToken);

        if (delivery == PushDelivery.Unregistered)
        {
            await ForgetAsync(token, cancellationToken);
        }
    }

    // Applications are uninstalled. Without this the table only grows, and it
    // grows with rows that are guaranteed to fail.
    private async Task ForgetAsync(string token, CancellationToken cancellationToken)
    {
        await db.DeviceTokens
            .Where(device => device.Token == token)
            .ExecuteDeleteAsync(cancellationToken);

        logger.LogInformation("A device the push service no longer knows was removed.");
    }
}
