using System.Linq.Expressions;
using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Crud;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Listings;

internal sealed class AccommodationService(GostioDbContext db, ICurrentUser currentUser)
    : CrudService<
        Accommodation,
        AccommodationResponse,
        AccommodationSearchRequest,
        AccommodationCreateRequest,
        AccommodationUpdateRequest>(db, "accommodation"),
      IAccommodationService
{
    protected override string StillReferencedMessage =>
        "This accommodation has records that have to be kept. Withdraw it instead of deleting it.";

    protected override Expression<Func<Accommodation, AccommodationResponse>> Projection =>
        accommodation => new AccommodationResponse
        {
            Id = accommodation.Id,
            HostId = accommodation.HostId,
            HostName = accommodation.Host.FirstName + " " + accommodation.Host.LastName,
            Title = accommodation.Title,
            Description = accommodation.Description,
            AccommodationTypeId = accommodation.AccommodationTypeId,
            AccommodationTypeName = accommodation.AccommodationType.Name,
            AccommodationCategoryId = accommodation.AccommodationCategoryId,
            AccommodationCategoryName = accommodation.AccommodationCategory.Name,
            CityId = accommodation.CityId,
            CityName = accommodation.City.Name,
            CountryName = accommodation.City.Country.Name,
            Address = accommodation.Address,
            Latitude = accommodation.Latitude,
            Longitude = accommodation.Longitude,
            MaxGuests = accommodation.MaxGuests,
            Bedrooms = accommodation.Bedrooms,
            Bathrooms = accommodation.Bathrooms,
            PricePerNight = accommodation.PricePerNight,
            CleaningFee = accommodation.CleaningFee,
            IsActive = accommodation.IsActive,
            CreatedAt = accommodation.CreatedAt,
        };

    protected override IOrderedQueryable<Accommodation> Order(IQueryable<Accommodation> query) =>
        query
            .OrderBy(accommodation => accommodation.Title)
            .ThenBy(accommodation => accommodation.Id);

    // Answers 404 rather than 403 for a listing the caller cannot see, so an id
    // nobody may read does not become a way of learning that it exists.
    public override async Task<AccommodationResponse> GetAsync(
        int id,
        CancellationToken cancellationToken) =>
        await Visible(Set.AsNoTracking())
            .Where(accommodation => accommodation.Id == id)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(id);

    public override async Task<AccommodationResponse> UpdateAsync(
        int id,
        AccommodationUpdateRequest request,
        CancellationToken cancellationToken)
    {
        await RequireOwnListingAsync(id, cancellationToken);

        return await base.UpdateAsync(id, request, cancellationToken);
    }

    public override async Task DeleteAsync(int id, CancellationToken cancellationToken)
    {
        await RequireOwnListingAsync(id, cancellationToken);

        await base.DeleteAsync(id, cancellationToken);
    }

    protected override IQueryable<Accommodation> Filter(
        IQueryable<Accommodation> query,
        AccommodationSearchRequest search)
    {
        query = Visible(query);

        if (Trimmed(search.Title) is string title)
        {
            query = query.Where(accommodation => accommodation.Title.Contains(title));
        }

        if (search.CityId is int cityId)
        {
            query = query.Where(accommodation => accommodation.CityId == cityId);
        }

        if (search.AccommodationTypeId is int typeId)
        {
            query = query.Where(accommodation => accommodation.AccommodationTypeId == typeId);
        }

        if (search.AccommodationCategoryId is int categoryId)
        {
            query = query.Where(
                accommodation => accommodation.AccommodationCategoryId == categoryId);
        }

        if (search.HostId is int hostId)
        {
            query = query.Where(accommodation => accommodation.HostId == hostId);
        }

        if (search.MinPrice is decimal minPrice)
        {
            query = query.Where(accommodation => accommodation.PricePerNight >= minPrice);
        }

        if (search.MaxPrice is decimal maxPrice)
        {
            query = query.Where(accommodation => accommodation.PricePerNight <= maxPrice);
        }

        if (search.MinGuests is int guests)
        {
            query = query.Where(accommodation => accommodation.MaxGuests >= guests);
        }

        if (search.IsActive is bool isActive)
        {
            query = query.Where(accommodation => accommodation.IsActive == isActive);
        }

        return query;
    }

    protected override async Task<Accommodation> NewAsync(
        AccommodationCreateRequest request,
        CancellationToken cancellationToken)
    {
        var hostId = request.HostId ?? currentUser.RequireUserId();

        RequireOwnerOrAdministrator(hostId);
        await RequireHostAsync(hostId, nameof(request.HostId), cancellationToken);

        var accommodation = new Accommodation
        {
            HostId = hostId,
            CreatedAt = DateTime.UtcNow,
        };

        await ApplyUpsertAsync(request, accommodation, cancellationToken);

        return accommodation;
    }

    protected override async Task ApplyAsync(
        AccommodationUpdateRequest request,
        Accommodation accommodation,
        CancellationToken cancellationToken)
    {
        var isActive = request.IsActive ?? throw new ValidationException(
            nameof(request.IsActive), "Say whether the listing is published.");

        await ApplyUpsertAsync(request, accommodation, cancellationToken);

        accommodation.IsActive = isActive;
        accommodation.ModifiedAt = DateTime.UtcNow;
    }

    private async Task ApplyUpsertAsync(
        AccommodationUpsertRequest request,
        Accommodation accommodation,
        CancellationToken cancellationToken)
    {
        await RequireReferenceAsync(
            Db.Cities, request.CityId, nameof(request.CityId), "city", cancellationToken);

        await RequireReferenceAsync(
            Db.AccommodationTypes,
            request.AccommodationTypeId,
            nameof(request.AccommodationTypeId),
            "accommodation type",
            cancellationToken);

        await RequireReferenceAsync(
            Db.AccommodationCategories,
            request.AccommodationCategoryId,
            nameof(request.AccommodationCategoryId),
            "accommodation category",
            cancellationToken);

        accommodation.Title = request.Title.Trim();
        accommodation.Description = request.Description.Trim();
        accommodation.AccommodationTypeId = request.AccommodationTypeId;
        accommodation.AccommodationCategoryId = request.AccommodationCategoryId;
        accommodation.CityId = request.CityId;
        accommodation.Address = request.Address.Trim();
        accommodation.Latitude = request.Latitude;
        accommodation.Longitude = request.Longitude;
        accommodation.MaxGuests = request.MaxGuests;
        accommodation.Bedrooms = request.Bedrooms;
        accommodation.Bathrooms = request.Bathrooms;
        accommodation.PricePerNight = request.PricePerNight;
        accommodation.CleaningFee = request.CleaningFee;
    }

    // A withdrawn listing still belongs to its host and is still an
    // administrator's to manage, but nobody else browses it.
    private IQueryable<Accommodation> Visible(IQueryable<Accommodation> query)
    {
        if (currentUser.IsInRole(RoleNames.Administrator))
        {
            return query;
        }

        var callerId = currentUser.UserId;

        return query.Where(
            accommodation => accommodation.IsActive || accommodation.HostId == callerId);
    }

    // Read as a projection rather than loaded: a tracked row here is what
    // breaks the single-statement delete that follows it.
    private async Task RequireOwnListingAsync(int id, CancellationToken cancellationToken)
    {
        var hostId = await Set
            .AsNoTracking()
            .Where(accommodation => accommodation.Id == id)
            .Select(accommodation => (int?)accommodation.HostId)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw Missing(id);

        RequireOwnerOrAdministrator(hostId);
    }

    private void RequireOwnerOrAdministrator(int hostId)
    {
        if (currentUser.RequireUserId() == hostId
            || currentUser.IsInRole(RoleNames.Administrator))
        {
            return;
        }

        throw new ForbiddenException("A host may only work on their own listings.");
    }

    private async Task RequireHostAsync(
        int hostId,
        string field,
        CancellationToken cancellationToken)
    {
        var isHost = await Db.Users
            .AsNoTracking()
            .Where(user => user.Id == hostId)
            .AnyAsync(
                user => user.UserRoles.Any(assignment => assignment.Role.Name == RoleNames.Host),
                cancellationToken);

        if (!isHost)
        {
            throw new ValidationException(field, "This account does not host anything.");
        }
    }

    private static async Task RequireReferenceAsync<TEntity>(
        DbSet<TEntity> set,
        int id,
        string field,
        string noun,
        CancellationToken cancellationToken)
        where TEntity : class, IEntity
    {
        if (!await set.AsNoTracking().AnyAsync(entity => entity.Id == id, cancellationToken))
        {
            throw new ValidationException(field, $"No {noun} has this id.");
        }
    }
}
