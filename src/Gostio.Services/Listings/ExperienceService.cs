using System.Linq.Expressions;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Search;

namespace Gostio.Services.Listings;

internal sealed class ExperienceService(
    GostioDbContext db,
    ICurrentUser currentUser,
    ExperienceAccess access,
    ISearchRecorder searches,
    SearchClock clock)
    : ListingService<
        Experience,
        ExperienceResponse,
        ExperienceSearchRequest,
        ExperienceCreateRequest,
        ExperienceUpdateRequest>(db, currentUser, access, searches, clock, "experience"),
      IExperienceService
{
    protected override string StillReferencedMessage =>
        "This experience has records that have to be kept. Withdraw it instead of deleting it.";

    protected override Expression<Func<Experience, ExperienceResponse>> Projection =>
        experience => new ExperienceResponse
        {
            Id = experience.Id,
            HostId = experience.HostId,
            HostName = experience.Host.FirstName + " " + experience.Host.LastName,
            Title = experience.Title,
            Description = experience.Description,
            ExperienceCategoryId = experience.ExperienceCategoryId,
            ExperienceCategoryName = experience.ExperienceCategory.Name,
            CityId = experience.CityId,
            CityName = experience.City.Name,
            CountryName = experience.City.Country.Name,
            MeetingPoint = experience.MeetingPoint,
            Latitude = experience.Latitude,
            Longitude = experience.Longitude,
            DurationMinutes = experience.DurationMinutes,
            PricePerPerson = experience.PricePerPerson,
            IsActive = experience.IsActive,
            CoverPhotoId = experience.Photos
                .Where(photo => photo.IsCover)
                .Select(photo => (int?)photo.Id)
                .FirstOrDefault(),
            AverageRating = Db.Reviews
                .Where(review => review.Reservation.ExperienceSlot!.ExperienceId == experience.Id)
                .Average(review => (decimal?)review.Rating),
            ReviewCount = Db.Reviews
                .Count(review => review.Reservation.ExperienceSlot!.ExperienceId == experience.Id),
            IsFavorite = Db.Favorites.Any(favorite =>
                favorite.UserId == CallerId && favorite.ExperienceId == experience.Id),
            CreatedAt = experience.CreatedAt,
        };

    protected override IQueryable<Experience> Matching(
        IQueryable<Experience> query,
        ExperienceSearchRequest search)
    {
        if (search.CityId is int cityId)
        {
            query = query.Where(experience => experience.CityId == cityId);
        }

        if (search.ExperienceCategoryId is int categoryId)
        {
            query = query.Where(experience => experience.ExperienceCategoryId == categoryId);
        }

        if (search.MinPrice is decimal minPrice)
        {
            query = query.Where(experience => experience.PricePerPerson >= minPrice);
        }

        if (search.MaxPrice is decimal maxPrice)
        {
            query = query.Where(experience => experience.PricePerPerson <= maxPrice);
        }

        if (search.MaxDurationMinutes is int minutes)
        {
            query = query.Where(experience => experience.DurationMinutes <= minutes);
        }

        if (search.AvailableFrom is not null
            || search.AvailableTo is not null
            || search.Places is not null)
        {
            query = WithAnOpenTerm(query, search);
        }

        return query;
    }

    // The places left are counted here exactly as ExperienceSlotService reports
    // them, or a search calls open a term the slot says is full.
    private IQueryable<Experience> WithAnOpenTerm(
        IQueryable<Experience> query,
        ExperienceSearchRequest search)
    {
        RequireAWindow(search);

        var now = DateTime.UtcNow;
        var from = search.AvailableFrom ?? now;
        var to = search.AvailableTo;
        var places = search.Places ?? 1;

        return query.Where(experience => experience.Slots.Any(slot =>
            slot.IsActive
            && slot.StartTime > now
            && slot.StartTime >= from
            && (to == null || slot.StartTime <= to)
            && slot.Capacity - Db.Reservations
                .Where(reservation => reservation.ExperienceSlotId == slot.Id)
                .Where(ReservationQueries.IsActive(now))
                .Sum(reservation => reservation.GuestCount) >= places));
    }

    protected override SearchSignal Signal(ExperienceSearchRequest search) =>
        new()
        {
            Target = SearchTarget.Experiences,
            Term = Trimmed(search.Title),
            CityId = search.CityId,
            GuestCount = search.Places,
            MinPrice = search.MinPrice,
            MaxPrice = search.MaxPrice,
        };

    private static void RequireAWindow(ExperienceSearchRequest search)
    {
        if (search.AvailableFrom is DateTime from
            && search.AvailableTo is DateTime to
            && to < from)
        {
            throw new ValidationException(
                nameof(search.AvailableTo), "A window ends at or after the moment it starts.");
        }
    }

    protected override async Task<Experience> NewAsync(
        ExperienceCreateRequest request,
        CancellationToken cancellationToken)
    {
        var experience = new Experience
        {
            HostId = await RequireHostAsync(
                request.HostId, nameof(request.HostId), cancellationToken),
            CreatedAt = DateTime.UtcNow,
        };

        await ApplyUpsertAsync(request, experience, cancellationToken);

        return experience;
    }

    protected override async Task ApplyAsync(
        ExperienceUpdateRequest request,
        Experience experience,
        CancellationToken cancellationToken)
    {
        var isActive = request.IsActive ?? throw new ValidationException(
            nameof(request.IsActive), "Say whether the listing is published.");

        await ApplyUpsertAsync(request, experience, cancellationToken);

        experience.IsActive = isActive;
        experience.ModifiedAt = DateTime.UtcNow;
    }

    private async Task ApplyUpsertAsync(
        ExperienceUpsertRequest request,
        Experience experience,
        CancellationToken cancellationToken)
    {
        await RequireReferenceAsync(
            Db.Cities, request.CityId, nameof(request.CityId), "city", cancellationToken);

        await RequireReferenceAsync(
            Db.ExperienceCategories,
            request.ExperienceCategoryId,
            nameof(request.ExperienceCategoryId),
            "experience category",
            cancellationToken);

        experience.Title = request.Title.Trim();
        experience.Description = request.Description.Trim();
        experience.ExperienceCategoryId = request.ExperienceCategoryId;
        experience.CityId = request.CityId;
        experience.MeetingPoint = request.MeetingPoint.Trim();
        experience.Latitude = request.Latitude;
        experience.Longitude = request.Longitude;
        experience.DurationMinutes = request.DurationMinutes;
        experience.PricePerPerson = request.PricePerPerson;
    }
}
