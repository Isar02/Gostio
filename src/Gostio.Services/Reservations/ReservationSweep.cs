using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Services.Configuration;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Reservations;

internal sealed class ReservationSweep(
    GostioDbContext db,
    IReservationTransitionService transitions,
    IReservationNotices notices,
    WorkerSettings settings) : IReservationSweep
{
    public async Task<ReservationSweepReport> RunAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;

        var holds = await MoveAllAsync(
            db.Reservations.Where(ReservationQueries.IsALapsedHold(now)),
            ReservationStatusCode.Pending,
            ReservationStatusCode.Cancelled,
            ReservationHold.RanOut,
            settings.ReservationSweepBatch,
            cancellationToken);

        var finished = await MoveAllAsync(
            Finished(now),
            ReservationStatusCode.Confirmed,
            ReservationStatusCode.Completed,
            reason: null,
            settings.ReservationSweepBatch - holds.Moved - holds.Skipped,
            cancellationToken);

        return new ReservationSweepReport(
            holds.Moved, finished.Moved, holds.Skipped + finished.Skipped);
    }

    private IQueryable<Reservation> Finished(DateTime now)
    {
        var today = DateOnly.FromDateTime(now);

        return db.Reservations.Where(reservation =>
            reservation.ReservationStatusId == (int)ReservationStatusCode.Confirmed
            && (reservation.CheckOutDate <= today
                || (reservation.ExperienceSlot != null
                    && reservation.ExperienceSlot.StartTime.AddMinutes(
                        reservation.ExperienceSlot.DurationMinutes) <= now)));
    }

    private async Task<(int Moved, int Skipped)> MoveAllAsync(
        IQueryable<Reservation> due,
        ReservationStatusCode from,
        ReservationStatusCode to,
        string? reason,
        int budget,
        CancellationToken cancellationToken)
    {
        if (budget <= 0)
        {
            return (0, 0);
        }

        var dueIds = await due
            .AsNoTracking()
            .OrderBy(reservation => reservation.Id)
            .Take(budget)
            .Select(reservation => reservation.Id)
            .ToListAsync(cancellationToken);

        var moved = 0;
        var skipped = 0;

        foreach (var reservationId in dueIds)
        {
            // A reservation somebody moved between the read and here matches
            // no row, and the pass counts it rather than failing over it.
            try
            {
                await transitions.MoveAsync(
                    reservationId, (int)from, to, changedByUserId: null, reason, cancellationToken);

                await notices.MovedAsync(reservationId, to, cancellationToken);

                moved++;
            }
            catch (BusinessException)
            {
                skipped++;
            }
        }

        return (moved, skipped);
    }
}
