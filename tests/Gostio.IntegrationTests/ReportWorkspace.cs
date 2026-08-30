using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database.Entities;
using Gostio.Services.Reports;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

// The rows are written to the tables rather than made through the endpoints
// that own them. A report is a question about reading, and a test that answers
// it through a booking flow fails twice when the booking flow breaks — and it
// could not place a charge in 2019 at all.
internal sealed record ReportedPlace(int CityId, int TypeId, int CategoryId);

internal sealed class ReportWorkspace(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-a-reported-account";

    private readonly AccommodationWorkspace accommodations = new(fixture);

    public async Task<int> AListingAsync()
    {
        var (_, listing) = await accommodations.AListingAsync(Password);

        return listing;
    }

    public async Task<int> ABookingAsync(
        int listing,
        DateTime createdAt,
        decimal price = 500m,
        ReservationStatusCode status = ReservationStatusCode.Confirmed,
        int nights = 2)
    {
        var guest = await fixture.AddUserAsync(Password);
        var checkIn = DateOnly.FromDateTime(createdAt).AddDays(30);

        await using var db = fixture.CreateContext();

        var reservation = new Reservation
        {
            UserId = guest,
            AccommodationId = listing,
            CheckInDate = checkIn,
            CheckOutDate = checkIn.AddDays(nights),
            GuestCount = 2,
            ReservationStatusId = (int)status,
            ExpiresAt = createdAt.AddDays(1),
            AccommodationTotal = price,
            CleaningFee = 0m,
            TotalPrice = price,
            CreatedAt = createdAt,
        };

        db.Reservations.Add(reservation);

        await db.SaveChangesAsync();

        return reservation.Id;
    }

    public async Task CompletedAsync(int reservation, DateTime changedAt)
    {
        await using var db = fixture.CreateContext();

        db.ReservationStatusHistory.Add(new ReservationStatusHistory
        {
            ReservationId = reservation,
            PreviousStatusId = (int)ReservationStatusCode.Confirmed,
            NewStatusId = (int)ReservationStatusCode.Completed,
            ChangedAt = changedAt,
        });

        await db.SaveChangesAsync();
    }

    public async Task<int> AChargeAsync(
        int reservation,
        decimal amount,
        DateTime? processedAt,
        PaymentStatus status = PaymentStatus.Succeeded,
        string? currency = null)
    {
        await using var db = fixture.CreateContext();

        var payment = new Payment
        {
            ReservationId = reservation,
            StripePaymentIntentId = $"pi_{Guid.NewGuid():N}",
            Status = status,
            Amount = amount,
            Currency = currency ?? fixture.Stripe.Currency,
            CreatedAt = processedAt ?? DateTime.UtcNow,
            ProcessedAt = processedAt,
        };

        db.Payments.Add(payment);

        await db.SaveChangesAsync();

        return payment.Id;
    }

    public async Task ARefundAsync(
        int payment,
        decimal amount,
        DateTime? processedAt,
        RefundStatus status = RefundStatus.Succeeded)
    {
        await using var db = fixture.CreateContext();

        db.Refunds.Add(new Refund
        {
            PaymentId = payment,
            StripeRefundId = $"re_{Guid.NewGuid():N}",
            Status = status,
            Amount = amount,
            Reason = "A cancellation the policy paid back",
            CreatedAt = processedAt ?? DateTime.UtcNow,
            ProcessedAt = processedAt,
        });

        await db.SaveChangesAsync();
    }

    // A city and a category no other test writes into, so a report that counts
    // the whole catalogue still counts only what this test put there.
    public async Task<ReportedPlace> APlaceAsync(string label) =>
        new(
            await fixture.EnsureCityAsync($"City of {label}"),
            await fixture.EnsureAccommodationTypeAsync($"Type of {label}"),
            await fixture.EnsureAccommodationCategoryAsync($"Category of {label}"));

    public Task<int> AHostAsync(params string[] roles) =>
        fixture.AddUserAsync(Password, roles.Length == 0 ? [RoleNames.Host] : roles);

    public async Task<int> AnAccommodationAsync(
        ReportedPlace place,
        bool published = true,
        int? owner = null)
    {
        var host = owner ?? await AHostAsync();

        await using var db = fixture.CreateContext();

        var listing = new Accommodation
        {
            HostId = host,
            Title = $"A place {Guid.NewGuid():N}",
            Description = "A place to stay, described at the length a listing needs.",
            AccommodationTypeId = place.TypeId,
            AccommodationCategoryId = place.CategoryId,
            CityId = place.CityId,
            Address = "Ferhadija 1",
            Latitude = 43.8563m,
            Longitude = 18.4131m,
            MaxGuests = 4,
            Bedrooms = 2,
            Bathrooms = 1,
            PricePerNight = 100m,
            CleaningFee = 15m,
            IsActive = published,
            CreatedAt = DateTime.UtcNow,
        };

        db.Accommodations.Add(listing);

        await db.SaveChangesAsync();

        return listing.Id;
    }

    public async Task<int> AnExperienceCategoryAsync(string label) =>
        await fixture.EnsureExperienceCategoryAsync($"Category of {label}");

    public async Task<int> AnExperienceAsync(
        int cityId,
        int categoryId,
        bool published = true,
        int? owner = null)
    {
        var host = owner ?? await AHostAsync();

        await using var db = fixture.CreateContext();

        var listing = new Experience
        {
            HostId = host,
            Title = $"A thing to do {Guid.NewGuid():N}",
            Description = "Something to do, described at the length a listing needs.",
            ExperienceCategoryId = categoryId,
            CityId = cityId,
            MeetingPoint = "Under the clock",
            Latitude = 43.8563m,
            Longitude = 18.4131m,
            DurationMinutes = 120,
            PricePerPerson = 40m,
            IsActive = published,
            CreatedAt = DateTime.UtcNow,
        };

        db.Experiences.Add(listing);

        await db.SaveChangesAsync();

        return listing.Id;
    }

    public async Task<int> ATermAsync(int experience, DateTime startsAt)
    {
        await using var db = fixture.CreateContext();

        var slot = new ExperienceSlot
        {
            ExperienceId = experience,
            StartTime = startsAt,
            DurationMinutes = 120,
            Capacity = 10,
            CreatedAt = DateTime.UtcNow,
        };

        db.ExperienceSlots.Add(slot);

        await db.SaveChangesAsync();

        return slot.Id;
    }

    public async Task<int> ASeatedBookingAsync(
        int term,
        DateTime createdAt,
        int seats,
        decimal price = 40m,
        ReservationStatusCode status = ReservationStatusCode.Confirmed)
    {
        var guest = await fixture.AddUserAsync(Password);

        await using var db = fixture.CreateContext();

        var reservation = new Reservation
        {
            UserId = guest,
            ExperienceSlotId = term,
            GuestCount = seats,
            ReservationStatusId = (int)status,
            ExpiresAt = createdAt.AddDays(1),
            PricePerPerson = price,
            TotalPrice = price * seats,
            CreatedAt = createdAt,
        };

        db.Reservations.Add(reservation);

        await db.SaveChangesAsync();

        return reservation.Id;
    }

    public async Task AReviewAsync(int reservation, int rating)
    {
        await using var db = fixture.CreateContext();

        db.Reviews.Add(new Review
        {
            ReservationId = reservation,
            Rating = rating,
            Comment = "A stay worth the words it took to say so.",
            CreatedAt = DateTime.UtcNow,
        });

        await db.SaveChangesAsync();
    }

    public async Task<ListingReportResponse> ListingsAsync(
        DateOnly? from,
        DateOnly? to,
        SearchTarget? target)
    {
        await using var services = fixture.BuildServices();

        return await services.GetRequiredService<IReportService>().ListingsAsync(
            new ListingReportRequest { From = from, To = to, Target = target }, default);
    }

    public async Task<RevenueReportResponse> RevenueAsync(DateOnly? from, DateOnly? to)
    {
        await using var services = fixture.BuildServices();

        return await services.GetRequiredService<IReportService>().RevenueAsync(
            new ReportRangeRequest { From = from, To = to }, default);
    }

    public async Task<RevenueReportResponse> MyRevenueAsync(
        int caller,
        DateOnly? from,
        DateOnly? to,
        params string[] roles)
    {
        await using var services = Of(caller, roles);

        return await services.GetRequiredService<IReportService>().MyRevenueAsync(
            new ReportRangeRequest { From = from, To = to }, default);
    }

    public async Task<ListingReportResponse> MyListingsAsync(
        int caller,
        DateOnly? from,
        DateOnly? to,
        SearchTarget target,
        params string[] roles)
    {
        await using var services = Of(caller, roles);

        return await services.GetRequiredService<IReportService>().MyListingsAsync(
            new ListingReportRequest { From = from, To = to, Target = target }, default);
    }

    private ServiceProvider Of(int caller, params string[] roles) =>
        fixture.BuildServices(ListingWorkspace.Caller(
            caller, roles.Length == 0 ? [RoleNames.Host] : roles));
}
