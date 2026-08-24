using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Reservations;

internal sealed class ReservationTransitionService(GostioDbContext db)
    : IReservationTransitionService
{
    public async Task ChangeAsync(
        int reservationId,
        ReservationStatusCode to,
        int? changedByUserId,
        string? reason,
        CancellationToken cancellationToken)
    {
        var changedAt = DateTime.UtcNow;

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        var current = await db.Reservations
            .AsNoTracking()
            .Where(reservation => reservation.Id == reservationId)
            .Select(reservation => (int?)reservation.ReservationStatusId)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException($"Reservation {reservationId} does not exist.");

        var from = ReservationStateMachine.RequireKnown(current);

        ReservationStateMachine.RequireAllowed(from, to);

        var normalizedReason = ReservationStateMachine.RequireReason(to, reason);

        var fromId = (int)from;
        var toId = (int)to;

        var affectedRows = await db.Reservations
            .Where(reservation =>
                reservation.Id == reservationId && reservation.ReservationStatusId == fromId)
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
            PreviousStatusId = fromId,
            NewStatusId = toId,
            ChangedByUserId = changedByUserId,
            ChangedAt = changedAt,
            Reason = normalizedReason,
        });

        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
    }
}
