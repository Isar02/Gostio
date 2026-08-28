using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Listings;

internal sealed class AccommodationAmenityService(GostioDbContext db, AccommodationAccess access)
    : IAccommodationAmenityService
{
    private static readonly Expression<Func<AccommodationAmenity, LookupResponse>> Projection =
        offering => new LookupResponse
        {
            Id = offering.AmenityId,
            Name = offering.Amenity.Name,
        };

    // The count and not the page decides which 404 to raise: a page past the
    // last row is empty on a listing that is there and offers something.
    public async Task<PagedResult<LookupResponse>> GetAsync(
        int accommodationId,
        PagedRequest request,
        CancellationToken cancellationToken)
    {
        var offered = await Ordered(Visible(accommodationId))
            .ToPagedResultAsync(request, Projection, cancellationToken);

        if (offered.TotalCount == 0)
        {
            await access.RequireVisibleAsync(accommodationId, cancellationToken);
        }

        return offered;
    }

    public async Task<IReadOnlyList<LookupResponse>> SetAsync(
        int accommodationId,
        AccommodationAmenitiesRequest request,
        CancellationToken cancellationToken)
    {
        await access.RequireOwnedAsync(accommodationId, cancellationToken);

        var wanted = await RequireAmenityIdsAsync(request, cancellationToken);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await access.LockAsync(accommodationId, cancellationToken);

        var held = await db.AccommodationAmenities
            .Where(offering => offering.AccommodationId == accommodationId)
            .ToListAsync(cancellationToken);

        db.AccommodationAmenities.RemoveRange(
            held.Where(offering => !wanted.Contains(offering.AmenityId)));

        db.AccommodationAmenities.AddRange(wanted
            .Where(amenityId => held.All(offering => offering.AmenityId != amenityId))
            .Select(amenityId => new AccommodationAmenity
            {
                AccommodationId = accommodationId,
                AmenityId = amenityId,
            }));

        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return await ReadAsync(ForListing(accommodationId), cancellationToken);
    }

    private async Task<List<int>> RequireAmenityIdsAsync(
        AccommodationAmenitiesRequest request,
        CancellationToken cancellationToken)
    {
        var field = nameof(request.AmenityIds);

        var wanted = (request.AmenityIds ?? throw new ValidationException(
                field, "Send the amenities this accommodation offers."))
            .Distinct()
            .ToList();

        var found = await db.Amenities
            .AsNoTracking()
            .Where(amenity => wanted.Contains(amenity.Id))
            .Select(amenity => amenity.Id)
            .ToListAsync(cancellationToken);

        var unknown = wanted.Except(found).ToList();

        if (unknown.Count > 0)
        {
            throw new ValidationException(
                field, $"No amenity has the id {string.Join(", ", unknown)}.");
        }

        return wanted;
    }

    private IQueryable<AccommodationAmenity> ForListing(int accommodationId) =>
        db.AccommodationAmenities
            .AsNoTracking()
            .Where(offering => offering.AccommodationId == accommodationId);

    private IQueryable<AccommodationAmenity> Visible(int accommodationId) =>
        ForListing(accommodationId)
            .Where(offering => access.VisibleListings()
                .Any(listing => listing.Id == offering.AccommodationId));

    private static IOrderedQueryable<AccommodationAmenity> Ordered(
        IQueryable<AccommodationAmenity> offerings) =>
        offerings.OrderBy(offering => offering.Amenity.Name);

    private static async Task<IReadOnlyList<LookupResponse>> ReadAsync(
        IQueryable<AccommodationAmenity> offerings,
        CancellationToken cancellationToken) =>
        await Ordered(offerings).Select(Projection).ToListAsync(cancellationToken);
}
