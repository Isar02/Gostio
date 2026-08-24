using System.Linq.Expressions;
using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Reservations;

internal sealed class ReservationAccess(GostioDbContext db, ICurrentUser currentUser)
{
    private static Expression<Func<Reservation, ReservationResponse>> Projection =>
        reservation => new ReservationResponse
        {
            Id = reservation.Id,
            UserId = reservation.UserId,
            AccommodationId = reservation.AccommodationId,
            ExperienceSlotId = reservation.ExperienceSlotId,
            CheckInDate = reservation.CheckInDate,
            CheckOutDate = reservation.CheckOutDate,
            GuestCount = reservation.GuestCount,
            ReservationStatusId = reservation.ReservationStatusId,
            Status = reservation.ReservationStatus.Code,
            ExpiresAt = reservation.ExpiresAt,
            AccommodationTotal = reservation.AccommodationTotal,
            CleaningFee = reservation.CleaningFee,
            PricePerPerson = reservation.PricePerPerson,
            TotalPrice = reservation.TotalPrice,
            CreatedAt = reservation.CreatedAt,
        };

    // The guest who booked, the host whose listing was booked, and an
    // administrator over both. To anybody else a reservation answers 404 rather
    // than 403: an id nobody may read must not become a way of learning that it
    // exists. This composes into the statement that reads the row, so nothing
    // can authorise from one read and then decide from another.
    private IQueryable<Reservation> Reachable()
    {
        var query = db.Reservations.AsNoTracking();

        if (currentUser.IsInRole(RoleNames.Administrator))
        {
            return query;
        }

        var callerId = currentUser.RequireUserId();

        return query.Where(reservation =>
            reservation.UserId == callerId
            || (reservation.Accommodation != null && reservation.Accommodation.HostId == callerId)
            || (reservation.ExperienceSlot != null
                && reservation.ExperienceSlot.Experience.HostId == callerId));
    }

    public async Task<ReservationResponse> ReadAsync(
        int reservationId,
        CancellationToken cancellationToken) =>
        await Of(reservationId)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(reservationId);

    public async Task<ReservationView> RequireReachableAsync(
        int reservationId,
        CancellationToken cancellationToken) =>
        await Of(reservationId)
            .Select(reservation => new ReservationView
            {
                StatusId = reservation.ReservationStatusId,
                HostId = reservation.AccommodationId != null
                    ? reservation.Accommodation!.HostId
                    : reservation.ExperienceSlot!.Experience.HostId,
                AccommodationId = reservation.AccommodationId,
                ExperienceId = reservation.ExperienceSlot != null
                    ? (int?)reservation.ExperienceSlot.ExperienceId
                    : null,
                ExperienceSlotId = reservation.ExperienceSlotId,
                CheckInDate = reservation.CheckInDate,
                CheckOutDate = reservation.CheckOutDate,
                GuestCount = reservation.GuestCount,
            })
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(reservationId);

    // A caller who was let through to the row already knows that it exists, so
    // a refusal here says so plainly instead of hiding behind a 404.
    public void RequireHostOrAdministrator(int hostId)
    {
        if (currentUser.RequireUserId() == hostId
            || currentUser.IsInRole(RoleNames.Administrator))
        {
            return;
        }

        throw new ForbiddenException("Only the host of a listing confirms a booking on it.");
    }

    public static NotFoundException Missing(int reservationId) =>
        new($"No reservation has the id {reservationId}.");

    private IQueryable<Reservation> Of(int reservationId) =>
        Reachable().Where(reservation => reservation.Id == reservationId);
}
