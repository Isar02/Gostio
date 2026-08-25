using Gostio.Model.Messaging;
using Gostio.Model.Validation;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Messaging;

internal sealed class NotificationWriter(GostioDbContext db) : INotificationWriter
{
    public Task WriteAsync(NotificationMessage message, CancellationToken cancellationToken)
    {
        db.Notifications.Add(new Notification
        {
            UserId = message.UserId,
            Type = message.Type,
            ReservationId = message.ReservationId,
            Title = Fit(message.Title, ColumnLengths.Title),
            Body = Fit(message.Body, ColumnLengths.NotificationBody),
            CreatedAt = message.CreatedAt,
        });

        return db.SaveChangesAsync(cancellationToken);
    }

    // Cut rather than refused: one character over would lose the whole notice.
    private static string Fit(string text, int length) =>
        text.Length <= length ? text : text[..length];
}
