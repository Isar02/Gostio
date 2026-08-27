using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Recommendations;

internal sealed class RecommendationService(
    GostioDbContext db,
    ICurrentUser currentUser,
    AccommodationSignals accommodations,
    ExperienceSignals experiences)
    : IRecommendationService
{
    public async Task<PagedResult<RecommendationResponse>> SearchAsync(
        RecommendationSearchRequest search,
        CancellationToken cancellationToken)
    {
        var userId = currentUser.RequireUserId();
        var target = Asked(search.Target);
        var catalogue = Catalogue(target);

        var engagements = await catalogue.EngagementsAsync(userId, cancellationToken);

        var candidates = await catalogue.CandidatesAsync(
            userId,
            [.. engagements.Select(engagement => engagement.ListingId).Distinct()],
            cancellationToken);

        var profile = TasteProfile.Build(
            await SearchesAsync(userId, target, cancellationToken),
            engagements,
            DateTime.UtcNow);

        return Page(RecommendationScoring.Rank(profile, candidates), search);
    }

    private Task<List<SearchedSignal>> SearchesAsync(
        int userId,
        SearchTarget target,
        CancellationToken cancellationToken) =>
        db.SearchHistory
            .AsNoTracking()
            .Where(row => row.UserId == userId && row.Target == target)
            .OrderByDescending(row => row.SearchedAt)
            .ThenByDescending(row => row.Id)
            .Take(RecommendationWeights.RecentSearches)
            .Select(row => new SearchedSignal(
                row.Term,
                row.CityId,
                row.GuestCount,
                row.MinPrice,
                row.MaxPrice,
                row.SearchedAt))
            .ToListAsync(cancellationToken);

    private IListingSignals Catalogue(SearchTarget target) =>
        target == SearchTarget.Accommodations ? accommodations : experiences;

    private static SearchTarget Asked(SearchTarget? target) =>
        target is SearchTarget named && Enum.IsDefined(named)
            ? named
            : throw new ValidationException(
                nameof(RecommendationSearchRequest.Target),
                "Say which catalogue the suggestions come from.");

    private static PagedResult<RecommendationResponse> Page(
        IReadOnlyList<ScoredCandidate> ranked,
        PagedRequest request) =>
        new()
        {
            Items = [.. ranked
                .Skip((int)Math.Min(request.Offset, ranked.Count))
                .Take(request.PageSize)
                .Select(Response)],
            Page = request.Page,
            PageSize = request.PageSize,
            TotalCount = ranked.Count,
        };

    private static RecommendationResponse Response(ScoredCandidate scored) => new()
    {
        ListingId = scored.Listing.ListingId,
        Target = scored.Listing.Target,
        Title = scored.Listing.Title,
        CityName = scored.Listing.CityName,
        CountryName = scored.Listing.CountryName,
        CategoryName = scored.Listing.CategoryName,
        Price = scored.Listing.Price,
        CoverPhotoId = scored.Listing.CoverPhotoId,
        AverageRating = scored.Listing.AverageRating,
        ReviewCount = scored.Listing.ReviewCount,
        Score = scored.Score,
        Reasons = scored.Reasons,
    };
}
