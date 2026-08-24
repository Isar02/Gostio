using System.Linq.Expressions;
using Gostio.Model.Responses;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Listings;

internal sealed class ExperiencePhotoService(GostioDbContext db, ExperienceAccess access)
    : ListingPhotoService<Experience, ExperiencePhoto>(db, access),
      IExperiencePhotoService
{
    protected override Expression<Func<ExperiencePhoto, ListingPhotoResponse>> Projection =>
        photo => new ListingPhotoResponse
        {
            Id = photo.Id,
            ListingId = photo.ExperienceId,
            ContentType = photo.ContentType,
            IsCover = photo.IsCover,
            DisplayOrder = photo.DisplayOrder,
            SizeInBytes = photo.Image.Length,
            UploadedAt = photo.UploadedAt,
        };

    protected override Expression<Func<ExperiencePhoto, bool>> BelongsToListing(int listingId) =>
        photo => photo.ExperienceId == listingId;

    protected override IQueryable<ExperiencePhoto> Visible(IQueryable<ExperiencePhoto> photos) =>
        photos.Where(photo => Access.VisibleListings()
            .Any(listing => listing.Id == photo.ExperienceId));

    protected override ExperiencePhoto NewPhoto(int listingId) =>
        new() { ExperienceId = listingId };
}
