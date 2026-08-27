using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Recommendations;

internal sealed record Engagement(int ListingId, EngagementKind Kind, int? Rating, DateTime At);

internal interface IListingSignals
{
    Task<IReadOnlyList<EngagedListing>> EngagementsAsync(
        int userId,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<Candidate>> CandidatesAsync(
        int userId,
        IReadOnlyCollection<int> engaged,
        CancellationToken cancellationToken);
}

internal abstract class ListingSignals<TListing>(GostioDbContext db) : IListingSignals
    where TListing : class, IListing
{
    protected GostioDbContext Db { get; } = db;

    protected DbSet<TListing> Set => Db.Set<TListing>();

    public async Task<IReadOnlyList<EngagedListing>> EngagementsAsync(
        int userId,
        CancellationToken cancellationToken)
    {
        var engagements = await EngagedAsync(userId, cancellationToken);

        if (engagements.Count == 0)
        {
            return [];
        }

        var ids = engagements.Select(engagement => engagement.ListingId).Distinct().ToList();

        var listings = await ReadAsync(
            Set.Where(listing => ids.Contains(listing.Id)),
            DateTime.UtcNow,
            cancellationToken);

        var byId = listings.ToDictionary(listing => listing.ListingId);

        return [.. engagements
            .Where(engagement => byId.ContainsKey(engagement.ListingId))
            .Select(engagement => new EngagedListing(
                engagement.ListingId,
                engagement.Kind,
                engagement.Rating,
                engagement.At,
                byId[engagement.ListingId].Price,
                byId[engagement.ListingId].Axes))];
    }

    public Task<IReadOnlyList<Candidate>> CandidatesAsync(
        int userId,
        IReadOnlyCollection<int> engaged,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;

        var offered = Offered(
            Set.Where(listing =>
                listing.IsActive
                && listing.HostId != userId
                && !engaged.Contains(listing.Id)),
            now);

        return ReadAsync(offered, now, cancellationToken);
    }

    protected abstract IQueryable<Engagement> Kept(int userId);

    protected abstract IQueryable<Engagement> Booked(int userId);

    protected abstract Task<IReadOnlyList<Candidate>> ReadAsync(
        IQueryable<TListing> listings,
        DateTime now,
        CancellationToken cancellationToken);

    protected virtual IQueryable<TListing> Offered(IQueryable<TListing> listings, DateTime now) =>
        listings;

    private async Task<IReadOnlyList<Engagement>> EngagedAsync(
        int userId,
        CancellationToken cancellationToken) =>
        [
            .. await Kept(userId).ToListAsync(cancellationToken),
            .. await Booked(userId).ToListAsync(cancellationToken),
        ];
}
