using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database.Entities;
using Gostio.Services.Listings;
using Gostio.Services.Reservations;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

internal sealed class ReservationWorkspace(DatabaseFixture fixture)
{
    public const string Password = "a-password-for-somebody-booking";

    private readonly AccommodationWorkspace listings = new(fixture);

    private readonly ExperienceWorkspace experiences = new(fixture);

    public async Task<int> APendingStayAsync(string password)
    {
        var (_, listing) = await listings.AListingAsync(password);
        var guest = await fixture.AddUserAsync(password, RoleNames.Guest);
        var checkIn = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));
        var now = DateTime.UtcNow;

        await using var db = fixture.CreateContext();

        var reservation = new Reservation
        {
            UserId = guest,
            AccommodationId = listing,
            CheckInDate = checkIn,
            CheckOutDate = checkIn.AddDays(3),
            GuestCount = 2,
            ReservationStatusId = (int)ReservationStatusCode.Pending,
            ExpiresAt = now.AddHours(24),
            AccommodationTotal = 300m,
            CleaningFee = 20m,
            TotalPrice = 320m,
            CreatedAt = now,
        };

        db.Reservations.Add(reservation);
        await db.SaveChangesAsync();

        return reservation.Id;
    }

    public async Task<(int Host, int Listing)> AListingAsync(
        decimal price = 100m,
        int maxGuests = 4)
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var request = ListingRequests.New(
            await listings.ReferencesAsync(),
            $"A listing {Guid.NewGuid():N}",
            price: price,
            maxGuests: maxGuests);

        var created = await AsAsync(
            host,
            RoleNames.Host,
            (IAccommodationService service) => service.CreateAsync(request, default));

        return (host, created.Id);
    }

    public async Task<(int Host, int Slot)> ATermAsync(
        int capacity,
        DateTime startsAt,
        decimal price = 40m)
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var request = ExperienceRequests.New(
            await experiences.ReferencesAsync(),
            $"An experience {Guid.NewGuid():N}",
            price: price);

        var experience = await AsAsync(
            host,
            RoleNames.Host,
            (IExperienceService service) => service.CreateAsync(request, default));

        var slot = await AsAsync(
            host,
            RoleNames.Host,
            (IExperienceSlotService service) => service.AddAsync(
                experience.Id,
                new ExperienceSlotCreateRequest { StartTime = startsAt, Capacity = capacity },
                default));

        return (host, slot.Id);
    }

    public async Task<int> AnotherTermAsync(
        int host,
        int slot,
        DateTime startsAt,
        int capacity = 10)
    {
        var experienceId = await ExperienceOfAsync(slot);

        var added = await AsAsync(
            host,
            RoleNames.Host,
            (IExperienceSlotService service) => service.AddAsync(
                experienceId,
                new ExperienceSlotCreateRequest { StartTime = startsAt, Capacity = capacity },
                default));

        return added.Id;
    }

    public Task<int> AnExperienceWithoutTermsAsync(int host) =>
        experiences.CreateAsync(host, $"An experience {Guid.NewGuid():N}");

    public async Task CloseTermAsync(int host, int slot, int capacity)
    {
        var experienceId = await ExperienceOfAsync(slot);

        await AsAsync(
            host,
            RoleNames.Host,
            (IExperienceSlotService service) => service.UpdateAsync(
                experienceId,
                slot,
                new ExperienceSlotUpdateRequest { Capacity = capacity, IsActive = false },
                default));
    }

    public Task<int> AGuestAsync() => fixture.AddUserAsync(Password, RoleNames.Guest);

    public Task CloseAsync(int host, int listing, DateOnly from, DateOnly to) =>
        AddExceptionAsync(host, listing, from, to, isAvailable: false, priceOverride: null);

    public Task RepriceAsync(int host, int listing, DateOnly from, DateOnly to, decimal price) =>
        AddExceptionAsync(host, listing, from, to, isAvailable: true, priceOverride: price);

    public async Task DeleteTermAsync(int host, int slot, params IInterceptor[] interceptors)
    {
        var experienceId = await ExperienceOfAsync(slot);

        await AsAsync(
            host,
            RoleNames.Host,
            async (IExperienceSlotService service) =>
            {
                await service.DeleteAsync(experienceId, slot, default);

                return true;
            },
            interceptors);
    }

    public Task<ReservationResponse> BookAsync(
        int guest,
        ReservationCreateRequest request,
        params IInterceptor[] interceptors) =>
        AsAsync(
            guest,
            RoleNames.Guest,
            (IReservationService service) => service.CreateAsync(request, default),
            interceptors);

    public Task<ReservationResponse> BookStayAsync(
        int guest,
        int listing,
        DateOnly checkIn,
        int nights,
        int guestCount = 2) =>
        BookAsync(guest, new ReservationCreateRequest
        {
            AccommodationId = listing,
            CheckInDate = checkIn,
            CheckOutDate = checkIn.AddDays(nights),
            GuestCount = guestCount,
        });

    public Task<ReservationResponse> BookTermAsync(
        int guest,
        int slot,
        int guestCount,
        params IInterceptor[] interceptors) =>
        BookAsync(
            guest,
            new ReservationCreateRequest { ExperienceSlotId = slot, GuestCount = guestCount },
            interceptors);

    public async Task CancelAsync(int reservationId)
    {
        var from = (int)await StatusOfAsync(reservationId);

        await using var services = fixture.BuildServices(new AnonymousUser());

        await services
            .GetRequiredService<IReservationTransitionService>()
            .MoveAsync(
                reservationId, from, ReservationStatusCode.Cancelled, null, "Called off", default);
    }

    public Task<ReservationResponse> ConfirmAsync(
        int actor,
        string role,
        int reservationId,
        params IInterceptor[] interceptors) =>
        AsAsync(
            actor,
            role,
            (IReservationMoveService service) => service.ConfirmAsync(reservationId, default),
            interceptors);

    public Task<ReservationResponse> CancelAsync(
        int actor,
        string role,
        int reservationId,
        string? reason) =>
        AsAsync(
            actor,
            role,
            (IReservationMoveService service) => service.CancelAsync(
                reservationId, new ReservationCancelRequest { Reason = reason }, default));

    public Task<ReservationResponse> ReadAsync(int actor, string role, int reservationId) =>
        AsAsync(
            actor,
            role,
            (IReservationService service) => service.GetAsync(reservationId, default));

    public Task<PagedResult<ExperienceResponse>> SearchExperiencesAsync(
        int actor,
        string role,
        ExperienceSearchRequest search) =>
        AsAsync(
            actor,
            role,
            (IExperienceService service) => service.SearchAsync(search, default));

    public Task<PagedResult<ReservationResponse>> ListAsync(
        int actor,
        string role,
        ReservationSearchRequest search) =>
        AsAsync(
            actor,
            role,
            (IReservationService service) => service.SearchAsync(search, default));

    public async Task<string> TitleOfAsync(int accommodationId)
    {
        await using var db = fixture.CreateContext();

        return await db.Accommodations
            .AsNoTracking()
            .Where(listing => listing.Id == accommodationId)
            .Select(listing => listing.Title)
            .SingleAsync();
    }

    // A hold whose deadline has passed and which no sweep has reached: still
    // pending, and holding nothing. The booking moves back with the deadline,
    // because CK_Reservations_Expiry keeps the one after the other.
    public async Task LapseAsync(int reservationId)
    {
        var lapsed = DateTime.UtcNow.AddMinutes(-1);

        await using var db = fixture.CreateContext();

        await db.Reservations
            .Where(reservation => reservation.Id == reservationId)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(reservation => reservation.CreatedAt, lapsed.AddHours(-24))
                .SetProperty(reservation => reservation.ExpiresAt, lapsed));
    }

    // Moves when the booking was made without moving what it books, so a test
    // can leave the grace period behind. `ExpiresAt` follows it, because
    // CK_Reservations_Expiry keeps the one after the other.
    public async Task AgeAsync(int reservationId, TimeSpan by)
    {
        await using var db = fixture.CreateContext();

        var clocks = await db.Reservations
            .AsNoTracking()
            .Where(reservation => reservation.Id == reservationId)
            .Select(reservation => new { reservation.CreatedAt, reservation.ExpiresAt })
            .SingleAsync();

        await db.Reservations
            .Where(reservation => reservation.Id == reservationId)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(reservation => reservation.CreatedAt, clocks.CreatedAt - by)
                .SetProperty(reservation => reservation.ExpiresAt, clocks.ExpiresAt - by));
    }

    // Moves when the booking was called off without moving anything else, so a
    // test can put real time between the cancellation and the clock.
    public async Task BackdateTheCancellationAsync(int reservationId, TimeSpan by)
    {
        await using var db = fixture.CreateContext();

        var cancellation = await db.ReservationStatusHistory
            .AsNoTracking()
            .Where(history => history.ReservationId == reservationId
                && history.NewStatusId == (int)ReservationStatusCode.Cancelled)
            .OrderByDescending(history => history.Id)
            .Select(history => new { history.Id, history.ChangedAt })
            .FirstAsync();

        await db.ReservationStatusHistory
            .Where(history => history.Id == cancellation.Id)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(history => history.ChangedAt, cancellation.ChangedAt - by));
    }

    public async Task MoveTheStayAsync(int reservationId, DateOnly checkOut)
    {
        await using var db = fixture.CreateContext();

        await db.Reservations
            .Where(reservation => reservation.Id == reservationId)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(reservation => reservation.CheckInDate, checkOut.AddDays(-2))
                .SetProperty(reservation => reservation.CheckOutDate, checkOut));
    }

    public async Task StartTheTermAsync(int slotId, TimeSpan ago)
    {
        var startTime = DateTime.UtcNow - ago;

        await using var db = fixture.CreateContext();

        await db.ExperienceSlots
            .Where(slot => slot.Id == slotId)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(slot => slot.StartTime, startTime));
    }

    public async Task<ReservationSweepReport> SweepAsync(
        int batch = 200,
        params IInterceptor[] interceptors)
    {
        await using var services = fixture.BuildSweep(batch, interceptors);

        return await services.GetRequiredService<IReservationSweep>().RunAsync(default);
    }

    public Task<int> AnAdministratorAsync() =>
        fixture.AddUserAsync(Password, RoleNames.Administrator);

    public async Task<ReservationStatusCode> StatusOfAsync(int reservationId)
    {
        await using var db = fixture.CreateContext();

        return (ReservationStatusCode)await db.Reservations
            .Where(reservation => reservation.Id == reservationId)
            .Select(reservation => reservation.ReservationStatusId)
            .SingleAsync();
    }

    public async Task<IReadOnlyList<ReservationStatusHistory>> HistoryOfAsync(int reservationId)
    {
        await using var db = fixture.CreateContext();

        return await db.ReservationStatusHistory
            .AsNoTracking()
            .Where(history => history.ReservationId == reservationId)
            .OrderBy(history => history.ChangedAt)
            .ThenBy(history => history.Id)
            .ToListAsync();
    }

    private Task AddExceptionAsync(
        int host,
        int listing,
        DateOnly from,
        DateOnly to,
        bool isAvailable,
        decimal? priceOverride) =>
        AsAsync(
            host,
            RoleNames.Host,
            (IAccommodationAvailabilityService service) => service.AddAsync(
                listing,
                new AccommodationAvailabilityRequest
                {
                    StartDate = from,
                    EndDate = to,
                    IsAvailable = isAvailable,
                    PriceOverride = priceOverride,
                },
                default));

    public async Task<int> ExperienceOfAsync(int slotId)
    {
        await using var db = fixture.CreateContext();

        return await db.ExperienceSlots
            .AsNoTracking()
            .Where(slot => slot.Id == slotId)
            .Select(slot => slot.ExperienceId)
            .SingleAsync();
    }

    private async Task<TResult> AsAsync<TService, TResult>(
        int userId,
        string role,
        Func<TService, Task<TResult>> work,
        params IInterceptor[] interceptors)
        where TService : notnull
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(userId, role), interceptors);

        return await work(services.GetRequiredService<TService>());
    }
}
