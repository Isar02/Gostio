using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Gostio.Services.Reservations;

internal sealed class ReservationTransitionService(GostioDbContext db)
    : IReservationTransitionService
{
    public async Task<DateTime> MoveAsync(
        int reservationId,
        int fromStatusId,
        ReservationStatusCode to,
        int? changedByUserId,
        string? reason,
        CancellationToken cancellationToken)
    {
        var changedAt = DateTime.UtcNow;

        var from = ReservationStateMachine.RequireKnown(fromStatusId);

        ReservationStateMachine.RequireAllowed(from, to);

        var normalizedReason = ReservationStateMachine.RequireReason(to, reason);

        // A confirmation has taken the listing lock in a transaction of its own
        // and the move belongs inside it. A caller that brought none is given
        // one, because the update and the history row are two statements.
        await using var owned = db.Database.CurrentTransaction is null
            ? await db.Database.BeginTransactionAsync(cancellationToken)
            : (IDbContextTransaction?)null;

        var toId = (int)to;

        // The update names the status the caller read, so a caller that lost a
        // race matches no row. That failure is not the refusal above: the move
        // was allowed and somebody else made it first, and a retry can succeed.
        var affectedRows = await db.Reservations
            .Where(reservation =>
                reservation.Id == reservationId
                && reservation.ReservationStatusId == fromStatusId)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(
                    reservation => reservation.ReservationStatusId, toId),
                cancellationToken);

        if (affectedRows == 0)
        {
            throw new BusinessException(
                $"The reservation moved while it was being changed to {to}. Read it again.");
        }

        db.ReservationStatusHistory.Add(new ReservationStatusHistory
        {
            ReservationId = reservationId,
            PreviousStatusId = fromStatusId,
            NewStatusId = toId,
            ChangedByUserId = changedByUserId,
            ChangedAt = changedAt,
            Reason = normalizedReason,
        });

        await db.SaveChangesAsync(cancellationToken);

        if (owned is not null)
        {
            await owned.CommitAsync(cancellationToken);
        }

        return changedAt;
    }
}
