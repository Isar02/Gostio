using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Gostio.Services.Reservations;

internal sealed class ReservationService(
    GostioDbContext db,
    ICurrentUser currentUser,
    AccommodationAccess accommodations,
    ExperienceAccess experiences) : IReservationService
{
    public async Task<ReservationResponse> CreateAsync(
        ReservationCreateRequest request,
        CancellationToken cancellationToken)
    {
        var guestId = currentUser.RequireUserId();

        return request.AccommodationId is int accommodationId
            ? await CreateStayAsync(accommodationId, request, guestId, cancellationToken)
            : await CreateTermAsync(RequiredSlot(request), request, guestId, cancellationToken);
    }

    private async Task<ReservationResponse> CreateStayAsync(
        int accommodationId,
        ReservationCreateRequest request,
        int guestId,
        CancellationToken cancellationToken)
    {
        if (request.ExperienceSlotId is not null)
        {
            throw new ValidationException(
                nameof(request.ExperienceSlotId),
                "A reservation books a stay or a term, not both.");
        }

        var guestCount = RequiredGuestCount(request);
        var (checkIn, checkOut) = RequiredNights(request);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await accommodations.LockAsync(accommodationId, cancellationToken);

        // Everything below is decided on this instant, read after the wait for
        // the lock. A call that queued behind another booking would otherwise
        // measure the world against the clock it arrived on.
        var now = DateTime.UtcNow;

        RequireTheStayIsStillAhead(checkIn, now);

        var listing = await db.Accommodations
            .AsNoTracking()
            .Where(candidate => candidate.Id == accommodationId && candidate.IsActive)
            .Select(candidate => new
            {
                candidate.HostId,
                candidate.MaxGuests,
                candidate.PricePerNight,
                candidate.CleaningFee,
            })
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw accommodations.Missing(accommodationId);

        RequireSomebodyElsesListing(listing.HostId, guestId);

        if (guestCount > listing.MaxGuests)
        {
            throw new BusinessException(
                $"This place sleeps {listing.MaxGuests} and the booking is for {guestCount}.");
        }

        var exceptions = await db.AccommodationAvailability
            .AsNoTracking()
            .Where(range => range.AccommodationId == accommodationId
                && range.StartDate < checkOut
                && range.EndDate >= checkIn)
            .Select(range => new
            {
                range.StartDate,
                range.EndDate,
                range.IsAvailable,
                range.PriceOverride,
            })
            .ToListAsync(cancellationToken);

        if (exceptions.Exists(range => !range.IsAvailable))
        {
            throw new BusinessException("The host has closed part of these dates.");
        }

        var taken = await db.Reservations
            .AsNoTracking()
            .Where(other => other.AccommodationId == accommodationId
                && other.CheckInDate < checkOut
                && checkIn < other.CheckOutDate)
            .Where(ReservationQueries.IsActive(now))
            .AnyAsync(cancellationToken);

        if (taken)
        {
            throw new BusinessException("Part of these dates is already booked.");
        }

        var accommodationTotal = ReservationPricing.TotalForNights(
            checkIn,
            checkOut,
            listing.PricePerNight,
            [.. exceptions
                .Where(range => range.PriceOverride is not null)
                .Select(range => new PricedRange(
                    range.StartDate, range.EndDate, range.PriceOverride!.Value))]);

        var reservation = new Reservation
        {
            UserId = guestId,
            AccommodationId = accommodationId,
            CheckInDate = checkIn,
            CheckOutDate = checkOut,
            GuestCount = guestCount,
            ReservationStatusId = (int)ReservationStateMachine.Created,
            ExpiresAt = ReservationHold.Deadline(now, checkIn.ToDateTime(TimeOnly.MinValue)),
            AccommodationTotal = accommodationTotal,
            CleaningFee = listing.CleaningFee,
            TotalPrice = accommodationTotal + listing.CleaningFee,
            CreatedAt = now,
        };

        return await SaveAsync(reservation, guestId, now, transaction, cancellationToken);
    }

    private async Task<ReservationResponse> CreateTermAsync(
        int slotId,
        ReservationCreateRequest request,
        int guestId,
        CancellationToken cancellationToken)
    {
        if (request.CheckInDate is not null || request.CheckOutDate is not null)
        {
            throw new ValidationException(
                nameof(request.CheckInDate), "A term already carries its own dates.");
        }

        var guestCount = RequiredGuestCount(request);

        var experienceId = await db.ExperienceSlots
            .AsNoTracking()
            .Where(slot => slot.Id == slotId)
            .Select(slot => (int?)slot.ExperienceId)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw MissingSlot(slotId);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        // Lowering a slot's capacity takes this same lock, so the seats are
        // counted and the booking written on one side of that change or the
        // other. The term and the clock are both read inside it: the id above
        // was read outside and says only which lock to take.
        await experiences.LockAsync(experienceId, cancellationToken);

        var now = DateTime.UtcNow;

        var term = await db.ExperienceSlots
            .AsNoTracking()
            .Where(slot => slot.Id == slotId && slot.IsActive && slot.Experience.IsActive)
            .Select(slot => new
            {
                slot.StartTime,
                slot.Capacity,
                slot.Experience.HostId,
                slot.Experience.PricePerPerson,
            })
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw MissingSlot(slotId);

        RequireSomebodyElsesListing(term.HostId, guestId);

        if (term.StartTime <= now)
        {
            throw new BusinessException("This term has already started.");
        }

        var seatsTaken = await db.Reservations
            .AsNoTracking()
            .Where(other => other.ExperienceSlotId == slotId)
            .Where(ReservationQueries.IsActive(now))
            .SumAsync(other => other.GuestCount, cancellationToken);

        var placesLeft = term.Capacity - seatsTaken;

        if (guestCount > placesLeft)
        {
            throw new BusinessException(
                placesLeft == 0
                    ? "This term is full."
                    : $"This term has {placesLeft} left and the booking is for {guestCount}.");
        }

        var reservation = new Reservation
        {
            UserId = guestId,
            ExperienceSlotId = slotId,
            GuestCount = guestCount,
            ReservationStatusId = (int)ReservationStateMachine.Created,
            ExpiresAt = ReservationHold.Deadline(now, term.StartTime),
            PricePerPerson = term.PricePerPerson,
            TotalPrice = term.PricePerPerson * guestCount,
            CreatedAt = now,
        };

        return await SaveAsync(reservation, guestId, now, transaction, cancellationToken);
    }

    private async Task<ReservationResponse> SaveAsync(
        Reservation reservation,
        int guestId,
        DateTime now,
        IDbContextTransaction transaction,
        CancellationToken cancellationToken)
    {
        db.Reservations.Add(reservation);

        // One save, so a reservation cannot exist without the row that opens its
        // trail. The navigation carries the key the insert has not produced yet.
        db.ReservationStatusHistory.Add(new ReservationStatusHistory
        {
            Reservation = reservation,
            NewStatusId = (int)ReservationStateMachine.Created,
            ChangedByUserId = guestId,
            ChangedAt = now,
        });

        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return await ReadAsync(reservation.Id, cancellationToken);
    }

    private Task<ReservationResponse> ReadAsync(
        int reservationId,
        CancellationToken cancellationToken) =>
        db.Reservations
            .AsNoTracking()
            .Where(reservation => reservation.Id == reservationId)
            .Select(reservation => new ReservationResponse
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
            })
            .SingleAsync(cancellationToken);

    private static void RequireSomebodyElsesListing(int hostId, int guestId)
    {
        if (hostId == guestId)
        {
            throw new BusinessException("A host does not book their own listing.");
        }
    }

    private static int RequiredGuestCount(ReservationCreateRequest request)
    {
        var guestCount = request.GuestCount
            ?? throw new ValidationException(
                nameof(request.GuestCount), "Say how many people are coming.");

        if (guestCount < 1)
        {
            throw new ValidationException(
                nameof(request.GuestCount), "A booking is for at least one person.");
        }

        return guestCount;
    }

    private static int RequiredSlot(ReservationCreateRequest request) =>
        request.ExperienceSlotId
        ?? throw new ValidationException(
            nameof(request.AccommodationId), "Say what is being booked: a place or a term.");

    private static void RequireTheStayIsStillAhead(DateOnly checkIn, DateTime now)
    {
        if (checkIn < DateOnly.FromDateTime(now))
        {
            throw new ValidationException(
                nameof(ReservationCreateRequest.CheckInDate), "A stay begins today or later.");
        }
    }

    private static (DateOnly CheckIn, DateOnly CheckOut) RequiredNights(
        ReservationCreateRequest request)
    {
        var checkIn = request.CheckInDate
            ?? throw new ValidationException(
                nameof(request.CheckInDate), "Choose the day the stay begins.");

        var checkOut = request.CheckOutDate
            ?? throw new ValidationException(
                nameof(request.CheckOutDate), "Choose the day the stay ends.");

        if (checkOut <= checkIn)
        {
            throw new ValidationException(
                nameof(request.CheckOutDate), "A stay ends after the day it begins.");
        }

        return (checkIn, checkOut);
    }

    private static NotFoundException MissingSlot(int slotId) =>
        new($"No slot has the id {slotId}.");
}
