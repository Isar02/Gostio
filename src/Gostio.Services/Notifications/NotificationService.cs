using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Notifications;

internal sealed class NotificationService(GostioDbContext db, ICurrentUser currentUser)
    : INotificationService
{
    private static Expression<Func<Notification, NotificationResponse>> Projection =>
        notification => new NotificationResponse
        {
            Id = notification.Id,
            Type = notification.Type.ToString(),
            ReservationId = notification.ReservationId,
            Title = notification.Title,
            Body = notification.Body,
            IsRead = notification.ReadAt != null,
            ReadAt = notification.ReadAt,
            CreatedAt = notification.CreatedAt,
        };

    public Task<PagedResult<NotificationResponse>> SearchAsync(
        NotificationSearchRequest search,
        CancellationToken cancellationToken) =>
        Matching(Mine(), search)
            .OrderByDescending(notification => notification.CreatedAt)
            .ThenByDescending(notification => notification.Id)
            .ToPagedResultAsync(search, Projection, cancellationToken);

    public async Task<UnreadCountResponse> UnreadAsync(CancellationToken cancellationToken) =>
        new()
        {
            Unread = await Mine()
                .Where(notification => notification.ReadAt == null)
                .CountAsync(cancellationToken),
        };

    // Names the unread state, so a second marking keeps the first instant.
    public async Task<NotificationResponse> MarkReadAsync(
        int notificationId,
        CancellationToken cancellationToken)
    {
        DateTime? readAt = DateTime.UtcNow;

        await Mine()
            .Where(notification =>
                notification.Id == notificationId && notification.ReadAt == null)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(notification => notification.ReadAt, readAt),
                cancellationToken);

        return await Mine()
            .Where(notification => notification.Id == notificationId)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException($"No notification has the id {notificationId}.");
    }

    public async Task<UnreadCountResponse> MarkAllReadAsync(CancellationToken cancellationToken)
    {
        DateTime? readAt = DateTime.UtcNow;

        await Mine()
            .Where(notification => notification.ReadAt == null)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(notification => notification.ReadAt, readAt),
                cancellationToken);

        return await UnreadAsync(cancellationToken);
    }

    private static IQueryable<Notification> Matching(
        IQueryable<Notification> query,
        NotificationSearchRequest search)
    {
        if (search.IsRead is bool isRead)
        {
            query = isRead
                ? query.Where(notification => notification.ReadAt != null)
                : query.Where(notification => notification.ReadAt == null);
        }

        if (search.Type is { } type)
        {
            query = query.Where(notification => notification.Type == type);
        }

        return query;
    }

    // One person's, an administrator included: the owner composes into every
    // statement, so somebody else's id answers 404 like one that does not exist.
    private IQueryable<Notification> Mine()
    {
        var userId = currentUser.RequireUserId();

        return db.Notifications
            .AsNoTracking()
            .Where(notification => notification.UserId == userId);
    }
}
