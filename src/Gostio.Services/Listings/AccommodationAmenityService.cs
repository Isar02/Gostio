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
    public async Task<IReadOnlyList<LookupResponse>> GetAsync(
        int accommodationId,
        CancellationToken cancellationToken)
    {
        var offered = await ReadAsync(Visible(accommodationId), cancellationToken);

        if (offered.Count == 0)
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

    private static async Task<IReadOnlyList<LookupResponse>> ReadAsync(
        IQueryable<AccommodationAmenity> offerings,
        CancellationToken cancellationToken) =>
        await offerings
            .OrderBy(offering => offering.Amenity.Name)
            .Select(offering => new LookupResponse
            {
                Id = offering.AmenityId,
                Name = offering.Amenity.Name,
            })
            .ToListAsync(cancellationToken);
}
