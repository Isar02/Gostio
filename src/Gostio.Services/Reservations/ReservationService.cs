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
    ReservationAccess access,
    ReservationPlaces places,
    AccommodationAccess accommodations,
    IReservationNotices notices,
    TimeProvider clock) : IReservationService
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

    public Task<ReservationResponse> GetAsync(
        int reservationId,
        CancellationToken cancellationToken) =>
        access.ReadAsync(reservationId, cancellationToken);

    public Task<PagedResult<ReservationResponse>> SearchAsync(
        ReservationSearchRequest search,
        CancellationToken cancellationToken) =>
        Matching(access.Reachable(), search)
            .OrderByDescending(reservation => reservation.CreatedAt)
            .ThenByDescending(reservation => reservation.Id)
            .ToPagedResultAsync(search, ReservationAccess.Projection, cancellationToken);

    private IQueryable<Reservation> Matching(
        IQueryable<Reservation> query,
        ReservationSearchRequest search)
    {
        if (search.GuestId is int guestId)
        {
            query = query.Where(reservation => reservation.UserId == guestId);
        }

        if (search.HostId is int hostId)
        {
            query = query.Where(ReservationQueries.IsHostedBy(hostId));
        }

        if (search.AccommodationId is int accommodationId)
        {
            query = query.Where(reservation => reservation.AccommodationId == accommodationId);
        }

        if (search.ExperienceId is int experienceId)
        {
            query = query.Where(reservation =>
                reservation.ExperienceSlot != null
                && reservation.ExperienceSlot.ExperienceId == experienceId);
        }

        if (search.ExperienceSlotId is int slotId)
        {
            query = query.Where(reservation => reservation.ExperienceSlotId == slotId);
        }

        if (search.ReservationStatusId is int statusId)
        {
            query = query.Where(reservation => reservation.ReservationStatusId == statusId);
        }

        if (search.IsActive is bool isActive)
        {
            var now = clock.GetUtcNow().UtcDateTime;

            query = query.Where(isActive
                ? ReservationQueries.IsActive(now)
                : ReservationQueries.IsNotActive(now));
        }

        return query;
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

        await places.LockAccommodationAsync(accommodationId, cancellationToken);

        // Everything below is decided on this instant, read after the wait for
        // the lock. A call that queued behind another booking would otherwise
        // measure the world against the clock it arrived on.
        var now = clock.GetUtcNow().UtcDateTime;

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

        var ranges = await places.RangesOverAsync(
            accommodationId, checkIn, checkOut, cancellationToken);

        if (ranges.Any(range => !range.IsAvailable))
        {
            throw new BusinessException("The host has closed part of these dates.");
        }

        var taken = await places.AreTheNightsTakenAsync(
            accommodationId, checkIn, checkOut, now, null, cancellationToken);

        if (taken)
        {
            throw new BusinessException("Part of these dates is already booked.");
        }

        var accommodationTotal = ReservationPricing.TotalForNights(
            checkIn,
            checkOut,
            listing.PricePerNight,
            [.. ranges
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
            ExpiresAt = ReservationHold.Deadline(now, StayTimes.BeginsAt(checkIn)),
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

        // The term and the clock are both read inside the lock: the id above was
        // read outside and says only which lock to take.
        await places.LockExperienceAsync(experienceId, cancellationToken);

        var now = clock.GetUtcNow().UtcDateTime;

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

        var seatsTaken = await places.SeatsTakenAsync(slotId, now, null, cancellationToken);
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

        await notices.CreatedAsync(reservation.Id, cancellationToken);

        return await access.ReadAsync(reservation.Id, cancellationToken);
    }

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
        if (StayTimes.HasBegun(checkIn, now))
        {
            throw new ValidationException(
                nameof(ReservationCreateRequest.CheckInDate),
                $"A stay is booked before check-in, which is {StayTimes.CheckInText} on the day it "
                    + "begins.");
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
