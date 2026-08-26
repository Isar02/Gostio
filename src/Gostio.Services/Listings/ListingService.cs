using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Crud;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Gostio.Services.Search;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Listings;

internal abstract class ListingService<TListing, TResponse, TSearch, TCreate, TUpdate>(
    GostioDbContext db,
    ICurrentUser currentUser,
    ListingAccess<TListing> access,
    ISearchRecorder searches,
    SearchClock clock,
    string noun)
    : CrudService<TListing, TResponse, TSearch, TCreate, TUpdate>(db, noun)
    where TListing : class, IListing
    where TResponse : class
    where TSearch : ListingSearchRequest
{
    protected ListingAccess<TListing> Access { get; } = access;

    protected int? CallerId => currentUser.UserId;

    public override async Task<PagedResult<TResponse>> SearchAsync(
        TSearch search,
        CancellationToken cancellationToken)
    {
        var searchedAt = clock.Now();
        var page = await base.SearchAsync(search, cancellationToken);

        if (search.Page == 1)
        {
            await searches.RecordAsync(Signal(search), searchedAt, cancellationToken);
        }

        return page;
    }

    public override async Task<TResponse> GetAsync(int id, CancellationToken cancellationToken) =>
        await Access.Visible(Set.AsNoTracking())
            .Where(listing => listing.Id == id)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(id);

    public override async Task<TResponse> UpdateAsync(
        int id,
        TUpdate request,
        CancellationToken cancellationToken)
    {
        await Access.RequireOwnedAsync(id, cancellationToken);

        return await base.UpdateAsync(id, request, cancellationToken);
    }

    public override async Task DeleteAsync(int id, CancellationToken cancellationToken)
    {
        await Access.RequireOwnedAsync(id, cancellationToken);

        await base.DeleteAsync(id, cancellationToken);
    }

    // Sealed around the visibility test rather than left to each listing: a
    // search that forgot it would answer with the withdrawn rows of strangers,
    // and nothing in the list it returns would look wrong.
    protected sealed override IQueryable<TListing> Filter(
        IQueryable<TListing> query,
        TSearch search)
    {
        query = Access.Visible(query);

        if (Trimmed(search.Title) is string title)
        {
            query = query.Where(listing => listing.Title.Contains(title));
        }

        if (search.HostId is int hostId)
        {
            query = query.Where(listing => listing.HostId == hostId);
        }

        if (search.IsActive is bool isActive)
        {
            query = query.Where(listing => listing.IsActive == isActive);
        }

        return Matching(query, search);
    }

    protected abstract IQueryable<TListing> Matching(IQueryable<TListing> query, TSearch search);

    protected abstract SearchSignal Signal(TSearch search);

    protected override IOrderedQueryable<TListing> Order(IQueryable<TListing> query) =>
        query
            .OrderBy(listing => listing.Title)
            .ThenBy(listing => listing.Id);

    // Absent means the caller keeps the listing; an administrator names a host
    // instead, because they are not the one letting it out.
    protected async Task<int> RequireHostAsync(
        int? named,
        string field,
        CancellationToken cancellationToken)
    {
        var hostId = named ?? currentUser.RequireUserId();

        Access.RequireOwnerOrAdministrator(hostId);

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

        return hostId;
    }

    protected async Task RequireReferenceAsync<TEntity>(
        DbSet<TEntity> set,
        int id,
        string field,
        string reference,
        CancellationToken cancellationToken)
        where TEntity : class, IEntity
    {
        if (!await set.AsNoTracking().AnyAsync(entity => entity.Id == id, cancellationToken))
        {
            throw new ValidationException(field, $"No {reference} has this id.");
        }
    }
}
