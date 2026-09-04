using Gostio.Model.Enums;
using Gostio.Model.Messaging;
using Gostio.Services.Database;
using Gostio.Services.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Gostio.Services.Reservations;

internal sealed class ReservationNotices(
    GostioDbContext db,
    INotices notices,
    ILogger<ReservationNotices> logger) : IReservationNotices
{
    public Task CreatedAsync(int reservationId, CancellationToken cancellationToken) =>
        RaiseAsync(
            reservationId,
            NotificationType.ReservationCreated,
            BookingNoticeText.Created,
            cancellationToken);

    public Task MovedAsync(
        int reservationId,
        ReservationStatusCode to,
        CancellationToken cancellationToken) =>
        RaiseAsync(
            reservationId,
            NotificationType.ReservationStatusChanged,
            booking => BookingNoticeText.Moved(booking, to),
            cancellationToken);

    public Task PaidAsync(
        int reservationId,
        decimal amount,
        string currency,
        CancellationToken cancellationToken) =>
        RaiseAsync(
            reservationId,
            NotificationType.PaymentSucceeded,
            booking => BookingNoticeText.Paid(booking, amount, currency),
            cancellationToken);

    public Task RefundedAsync(
        int reservationId,
        decimal amount,
        string currency,
        CancellationToken cancellationToken) =>
        RaiseAsync(
            reservationId,
            NotificationType.RefundProcessed,
            booking => BookingNoticeText.Refunded(booking, amount, currency),
            cancellationToken);

    // The read is guarded as well as the publish: all of this runs after the
    // commit, so none of it may fail a booking or end a sweep pass.
    private async Task RaiseAsync(
        int reservationId,
        NotificationType type,
        Func<BookingParties, Told?> compose,
        CancellationToken cancellationToken)
    {
        try
        {
            var booking = await PartiesOfAsync(reservationId, cancellationToken);

            if (booking is null || compose(booking) is not Told told)
            {
                return;
            }

            await TellAsync(
                booking.Guest, booking.ReservationId, type, told.Guest, cancellationToken);

            if (told.Host is Words words)
            {
                await TellAsync(
                    booking.Host, booking.ReservationId, type, words, cancellationToken);
            }
        }
        catch (Exception failure) when (failure is not OperationCanceledException)
        {
            logger.LogError(
                failure,
                "No notice went out for the reservation {ReservationId} after it {Type}.",
                reservationId,
                type);
        }
    }

    private async Task TellAsync(
        BookingParty party,
        int reservationId,
        NotificationType type,
        Words words,
        CancellationToken cancellationToken)
    {
        var raisedAt = DateTime.UtcNow;

        await notices.NotifyAsync(
            new NotificationMessage
            {
                UserId = party.UserId,
                Type = type,
                ReservationId = reservationId,
                Title = words.Title,
                Body = words.Body,
                CreatedAt = raisedAt,
            },
            cancellationToken);

        await notices.SendAsync(
            new EmailMessage
            {
                ToEmail = party.Email,
                ToName = party.Name,
                Subject = words.Title,
                Body = words.Body,
            },
            cancellationToken);
    }

    // Chosen once, so the host and the title cannot come off different sides.
    private async Task<BookingParties?> PartiesOfAsync(
        int reservationId,
        CancellationToken cancellationToken)
    {
        var booked = await db.Reservations
            .AsNoTracking()
            .Where(reservation => reservation.Id == reservationId)
            .Select(reservation => new
            {
                reservation.Id,
                Guest = new BookingParty(
                    reservation.UserId,
                    reservation.User.FirstName + " " + reservation.User.LastName,
                    reservation.User.Email),
                Stay = reservation.Accommodation == null
                    ? null
                    : new BookedListing(
                        reservation.Accommodation.HostId,
                        reservation.Accommodation.Host.FirstName + " "
                            + reservation.Accommodation.Host.LastName,
                        reservation.Accommodation.Host.Email,
                        reservation.Accommodation.Title),
                Term = reservation.ExperienceSlot == null
                    ? null
                    : new BookedListing(
                        reservation.ExperienceSlot.Experience.HostId,
                        reservation.ExperienceSlot.Experience.Host.FirstName + " "
                            + reservation.ExperienceSlot.Experience.Host.LastName,
                        reservation.ExperienceSlot.Experience.Host.Email,
                        reservation.ExperienceSlot.Experience.Title),
                reservation.CheckInDate,
                reservation.CheckOutDate,
                SlotStartTime = reservation.ExperienceSlot == null
                    ? (DateTime?)null
                    : reservation.ExperienceSlot.StartTime,
            })
            .FirstOrDefaultAsync(cancellationToken);

        if (booked is null)
        {
            return null;
        }

        var listing = booked.Stay ?? booked.Term!;

        return new BookingParties(
            booked.Id,
            booked.Guest,
            new BookingParty(listing.HostId, listing.HostName, listing.HostEmail),
            listing.Title,
            booked.CheckInDate,
            booked.CheckOutDate,
            booked.SlotStartTime);
    }
}
