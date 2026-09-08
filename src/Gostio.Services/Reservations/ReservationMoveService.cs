using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Reservations;

internal sealed class ReservationMoveService(
    GostioDbContext db,
    ICurrentUser currentUser,
    ReservationAccess access,
    ReservationPlaces places,
    ReservationPreconditions preconditions,
    IReservationTransitionService transitions,
    ICancellationRefunds refunds,
    IReservationNotices notices) : IReservationMoveService
{
    public async Task<ReservationResponse> ConfirmAsync(
        int reservationId,
        CancellationToken cancellationToken)
    {
        var actorId = currentUser.RequireUserId();
        var booking = await access.RequireReachableAsync(reservationId, cancellationToken);

        access.RequireHostOrAdministrator(booking.HostId);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await LockAsync(booking, cancellationToken);

        var now = DateTime.UtcNow;

        // The move goes first, so a reservation somebody else moved is reported
        // as that rather than as a place that has gone. Nothing it writes is
        // visible before the commit, so the check below still takes it back.
        await transitions.MoveAsync(
            reservationId,
            booking.StatusId,
            ReservationStatusCode.Confirmed,
            actorId,
            reason: null,
            cancellationToken);

        await RequireThePlaceIsStillFreeAsync(reservationId, now, cancellationToken);

        await transaction.CommitAsync(cancellationToken);

        await notices.MovedAsync(
            reservationId, ReservationStatusCode.Confirmed, cancellationToken);

        return await access.ReadAsync(reservationId, cancellationToken);
    }

    public async Task<ReservationResponse> CancelAsync(
        int reservationId,
        ReservationCancelRequest request,
        CancellationToken cancellationToken)
    {
        var actorId = currentUser.RequireUserId();

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        // The lock comes before the read, not after it. A cancellation gives a
        // place back rather than taking one, so the listing needs no lock of its
        // own, but the status this moves from has to be the one that is true
        // once the queue has cleared: a settlement landing at the same instant
        // confirms the booking, and a caller holding a status read beforehand
        // would be told to read it again for no reason. What the booking owes
        // back is decided in the same transaction, so one that was paid for
        // cannot end without the row that says how much of it goes back.
        await ReservationLock.TakeAsync(db, reservationId, cancellationToken);

        var booking = await access.RequireReachableAsync(reservationId, cancellationToken);
        var cancelledAt = await transitions.MoveAsync(
            reservationId,
            booking.StatusId,
            ReservationStatusCode.Cancelled,
            actorId,
            request.Reason,
            cancellationToken);

        // Anybody but the guest is the service being withdrawn rather than
        // declined, an administrator included.
        await refunds.RecordAsync(
            new CancelledBooking(
                reservationId,
                booking.CreatedAt,
                booking.StartsAt,
                cancelledAt,
                ByTheGuest: actorId == booking.GuestId),
            cancellationToken);

        await transaction.CommitAsync(cancellationToken);

        await notices.MovedAsync(
            reservationId, ReservationStatusCode.Cancelled, cancellationToken);

        return await access.ReadAsync(reservationId, cancellationToken);
    }

    private Task LockAsync(ReservationView booking, CancellationToken cancellationToken) =>
        booking.AccommodationId is int accommodationId
            ? places.LockAccommodationAsync(accommodationId, cancellationToken)
            : places.LockExperienceAsync(booking.ExperienceId!.Value, cancellationToken);

    // A hold that lapsed stopped holding its place, so somebody else can have
    // taken it. What creation tested is tested again, on the instant read after
    // the wait for the lock, and by the same reader a settling charge asks, so
    // the two ways of confirming a booking cannot come to different answers.
    private async Task RequireThePlaceIsStillFreeAsync(
        int reservationId,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var refusal = await preconditions.WhyItCannotBeHonouredAsync(
            reservationId, now, cancellationToken);

        if (refusal is not null)
        {
            throw new BusinessException(refusal);
        }
    }
}
