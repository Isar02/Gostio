using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Favorites;

namespace Gostio.Tests.Favorites;

internal sealed class StubFavorites
    : IFavoriteService, IAccommodationFavoriteService, IExperienceFavoriteService
{
    public FavoriteSearchRequest? LastSearch { get; private set; }

    public int? LastKept { get; private set; }

    public int? LastDropped { get; private set; }

    public static FavoriteResponse Row(int listingId) => new()
    {
        Id = 1,
        AccommodationId = listingId,
        ListingTitle = "A place by the river",
        CityName = "Sarajevo",
        CountryName = "Bosnia and Herzegovina",
        Price = 90m,
        CoverPhotoId = 4,
        IsListingActive = true,
        CreatedAt = new DateTime(2026, 8, 25, 9, 0, 0, DateTimeKind.Utc),
    };

    public Task<PagedResult<FavoriteResponse>> SearchAsync(
        FavoriteSearchRequest search,
        CancellationToken cancellationToken)
    {
        LastSearch = search;

        return Task.FromResult(new PagedResult<FavoriteResponse>
        {
            Items = [Row(11)],
            Page = search.Page,
            PageSize = search.PageSize,
            TotalCount = 1,
        });
    }

    public Task<FavoriteResponse> AddAsync(int listingId, CancellationToken cancellationToken)
    {
        LastKept = listingId;

        return Task.FromResult(Row(listingId));
    }

    public Task RemoveAsync(int listingId, CancellationToken cancellationToken)
    {
        LastDropped = listingId;

        return Task.CompletedTask;
    }
}
