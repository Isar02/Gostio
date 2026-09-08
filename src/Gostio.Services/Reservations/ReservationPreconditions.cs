using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Reservations;

// What a pending booking still rests on, asked by both things that confirm one:
// the host's click and a charge settling. A refusal rather than an exception,
// because a settlement that finds the place gone has money to hand back. Every
// read runs inside the lock the caller took over the listing.
internal sealed class ReservationPreconditions(GostioDbContext db, ReservationPlaces places)
{
    public async Task<string?> WhyItCannotBeHonouredAsync(
        int reservationId,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var booking = await db.Reservations
            .AsNoTracking()
            .Where(reservation => reservation.Id == reservationId)
            .Select(reservation => new Booked(
                reservation.UserId,
                reservation.AccommodationId,
                reservation.ExperienceSlotId,
                reservation.CheckInDate,
                reservation.CheckOutDate,
                reservation.GuestCount))
            .FirstOrDefaultAsync(cancellationToken);

        // The caller that reads it next says so in its own words.
        if (booking is null)
        {
            return null;
        }

        return booking.AccommodationId is int accommodationId
            ? await WhyTheNightsAreGoneAsync(
                reservationId, accommodationId, booking, now, cancellationToken)
            : await WhyTheTermIsGoneAsync(reservationId, booking, now, cancellationToken);
    }

    private async Task<string?> WhyTheNightsAreGoneAsync(
        int reservationId,
        int accommodationId,
        Booked booking,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var checkIn = booking.CheckInDate!.Value;
        var checkOut = booking.CheckOutDate!.Value;

        if (checkIn < DateOnly.FromDateTime(now))
        {
            return "This stay has already begun.";
        }

        var ranges = await places.RangesOverAsync(
            accommodationId, checkIn, checkOut, cancellationToken);

        if (ranges.Any(range => !range.IsAvailable))
        {
            return "The host has closed part of these dates since the booking was made.";
        }

        var taken = await places.AreTheNightsTakenAsync(
            accommodationId, checkIn, checkOut, now, reservationId, cancellationToken);

        return taken ? "These dates were taken while this booking was pending." : null;
    }

    private async Task<string?> WhyTheTermIsGoneAsync(
        int reservationId,
        Booked booking,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var slotId = booking.ExperienceSlotId!.Value;

        var term = await db.ExperienceSlots
            .AsNoTracking()
            .Where(slot => slot.Id == slotId)
            .Select(slot => new { slot.StartTime, slot.Capacity, slot.IsActive })
            .FirstAsync(cancellationToken);

        if (term.StartTime <= now)
        {
            return "This term has already started.";
        }

        // A host may close a term the moment its last hold lapses.
        if (!term.IsActive)
        {
            return "The host has closed this term since the booking was made.";
        }

        var duplicate = await places.HoldsAPlaceAsync(
            slotId, booking.GuestId, now, reservationId, cancellationToken);

        if (duplicate)
        {
            return "This guest booked this term again while this booking was pending.";
        }

        var seatsTaken = await places.SeatsTakenAsync(
            slotId, now, reservationId, cancellationToken);

        return booking.GuestCount > term.Capacity - seatsTaken
            ? "This term ran out of room while this booking was pending."
            : null;
    }

    private sealed record Booked(
        int GuestId,
        int? AccommodationId,
        int? ExperienceSlotId,
        DateOnly? CheckInDate,
        DateOnly? CheckOutDate,
        int GuestCount);
}
