using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Recommendations;

namespace Gostio.Tests.Recommendations;

internal sealed class StubRecommendations : IRecommendationService
{
    public RecommendationSearchRequest? LastSearch { get; private set; }

    public Task<PagedResult<RecommendationResponse>> SearchAsync(
        RecommendationSearchRequest search,
        CancellationToken cancellationToken)
    {
        LastSearch = search;

        return Task.FromResult(new PagedResult<RecommendationResponse>
        {
            Items = [Row()],
            Page = search.Page,
            PageSize = search.PageSize,
            TotalCount = 1,
        });
    }

    private static RecommendationResponse Row() => new()
    {
        ListingId = 11,
        Target = SearchTarget.Accommodations,
        Title = "A place by the river",
        CityName = "Sarajevo",
        CountryName = "Bosnia and Herzegovina",
        CategoryName = "City break",
        Price = 90m,
        CoverPhotoId = 4,
        AverageRating = 4.5m,
        ReviewCount = 8,
        Score = 0.82,
        Reasons = [new RecommendationReasonResponse
        {
            Kind = RecommendationReasonKind.City,
            Detail = "Sarajevo",
        }],
    };
}
