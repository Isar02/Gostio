using System.Linq.Expressions;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Listings;

internal sealed class AccommodationPhotoService(GostioDbContext db, AccommodationAccess access)
    : ListingPhotoService<Accommodation, AccommodationPhoto>(db, access),
      IAccommodationPhotoService
{
    protected override Expression<Func<AccommodationPhoto, ListingPhotoResponse>> Projection =>
        photo => new ListingPhotoResponse
        {
            Id = photo.Id,
            ListingId = photo.AccommodationId,
            ContentType = photo.ContentType,
            IsCover = photo.IsCover,
            DisplayOrder = photo.DisplayOrder,
            SizeInBytes = photo.Image.Length,
            UploadedAt = photo.UploadedAt,
        };

    protected override Expression<Func<AccommodationPhoto, bool>> BelongsToListing(int listingId) =>
        photo => photo.AccommodationId == listingId;

    protected override IQueryable<AccommodationPhoto> Visible(
        IQueryable<AccommodationPhoto> photos) =>
        photos.Where(photo => Access.VisibleListings()
            .Any(listing => listing.Id == photo.AccommodationId));

    protected override AccommodationPhoto NewPhoto(int listingId) =>
        new() { AccommodationId = listingId };
}
