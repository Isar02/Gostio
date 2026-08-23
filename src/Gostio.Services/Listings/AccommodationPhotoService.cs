using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Listings;

internal sealed class AccommodationPhotoService(GostioDbContext db, AccommodationAccess access)
    : IAccommodationPhotoService
{
    private const string FileField = "File";

    private static Expression<Func<AccommodationPhoto, AccommodationPhotoResponse>> Projection =>
        photo => new AccommodationPhotoResponse
        {
            Id = photo.Id,
            AccommodationId = photo.AccommodationId,
            ContentType = photo.ContentType,
            IsCover = photo.IsCover,
            DisplayOrder = photo.DisplayOrder,
            SizeInBytes = photo.Image.Length,
            UploadedAt = photo.UploadedAt,
        };

    public async Task<PagedResult<AccommodationPhotoResponse>> SearchAsync(
        int accommodationId,
        PagedRequest request,
        CancellationToken cancellationToken)
    {
        await access.RequireVisibleAsync(accommodationId, cancellationToken);

        return await Ordered(accommodationId)
            .ToPagedResultAsync(request, Projection, cancellationToken);
    }

    public async Task<AccommodationPhotoResponse> GetAsync(
        int accommodationId,
        int photoId,
        CancellationToken cancellationToken)
    {
        await access.RequireVisibleAsync(accommodationId, cancellationToken);

        return await ReadAsync(accommodationId, photoId, cancellationToken);
    }

    public async Task<ImageContent> GetContentAsync(
        int accommodationId,
        int photoId,
        CancellationToken cancellationToken)
    {
        await access.RequireVisibleAsync(accommodationId, cancellationToken);

        return await Of(accommodationId, photoId)
            .Select(photo => new ImageContent(photo.Image, photo.ContentType))
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw Missing(photoId);
    }

    public async Task<AccommodationPhotoResponse> AddAsync(
        int accommodationId,
        byte[] content,
        CancellationToken cancellationToken)
    {
        await access.RequireOwnedAsync(accommodationId, cancellationToken);

        var contentType = RequireImage(content);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        var highest = await db.AccommodationPhotos
            .Where(photo => photo.AccommodationId == accommodationId)
            .MaxAsync(photo => (int?)photo.DisplayOrder, cancellationToken);

        var photo = new AccommodationPhoto
        {
            AccommodationId = accommodationId,
            Image = content,
            ContentType = contentType,
            DisplayOrder = (highest ?? -1) + 1,
            UploadedAt = DateTime.UtcNow,
        };

        db.AccommodationPhotos.Add(photo);

        await db.SaveChangesAsync(cancellationToken);

        // The first picture carries the cover, or a listing with photos has
        // none to show beside its title. The clause is inside the statement
        // rather than read first, so two uploads at once promote exactly one.
        await db.AccommodationPhotos
            .Where(candidate => candidate.Id == photo.Id
                && !db.AccommodationPhotos.Any(other =>
                    other.AccommodationId == accommodationId && other.IsCover))
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(candidate => candidate.IsCover, true),
                cancellationToken);

        await transaction.CommitAsync(cancellationToken);

        return await ReadAsync(accommodationId, photo.Id, cancellationToken);
    }

    public async Task<AccommodationPhotoResponse> SetCoverAsync(
        int accommodationId,
        int photoId,
        CancellationToken cancellationToken)
    {
        await access.RequireOwnedAsync(accommodationId, cancellationToken);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        // Cleared before the new one is set: one cover per listing is a unique
        // index, and the other order collides with it.
        await db.AccommodationPhotos
            .Where(photo => photo.AccommodationId == accommodationId && photo.IsCover)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(photo => photo.IsCover, false),
                cancellationToken);

        var promoted = await Of(accommodationId, photoId)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(photo => photo.IsCover, true),
                cancellationToken);

        if (promoted == 0)
        {
            throw Missing(photoId);
        }

        await transaction.CommitAsync(cancellationToken);

        return await ReadAsync(accommodationId, photoId, cancellationToken);
    }

    public async Task DeleteAsync(
        int accommodationId,
        int photoId,
        CancellationToken cancellationToken)
    {
        await access.RequireOwnedAsync(accommodationId, cancellationToken);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        var wasCover = await Of(accommodationId, photoId)
            .AsNoTracking()
            .Select(photo => (bool?)photo.IsCover)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw Missing(photoId);

        await Of(accommodationId, photoId).ExecuteDeleteAsync(cancellationToken);

        if (wasCover)
        {
            await PromoteNextAsync(accommodationId, cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
    }

    // A listing keeps a cover for as long as it has any photo left, or the row
    // stops showing a picture the moment the wrong one is removed.
    private async Task PromoteNextAsync(int accommodationId, CancellationToken cancellationToken)
    {
        var next = await Ordered(accommodationId)
            .Select(photo => (int?)photo.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (next is int id)
        {
            await db.AccommodationPhotos
                .Where(photo => photo.Id == id)
                .ExecuteUpdateAsync(
                    setters => setters.SetProperty(photo => photo.IsCover, true),
                    cancellationToken);
        }
    }

    private static string RequireImage(byte[] content)
    {
        if (content.Length == 0)
        {
            throw new ValidationException(FileField, "Choose an image to upload.");
        }

        if (content.Length > ImageRules.MaximumBytes)
        {
            throw new ValidationException(
                FileField,
                $"An image is at most {ImageRules.MaximumBytes / (1024 * 1024)} MB.");
        }

        return ImageRules.Detect(content)
            ?? throw new ValidationException(
                FileField,
                $"An image has to be one of {string.Join(", ", ImageRules.Allowed)}.");
    }

    private IQueryable<AccommodationPhoto> Of(int accommodationId, int photoId) =>
        db.AccommodationPhotos.Where(photo =>
            photo.AccommodationId == accommodationId && photo.Id == photoId);

    private IOrderedQueryable<AccommodationPhoto> Ordered(int accommodationId) =>
        db.AccommodationPhotos
            .AsNoTracking()
            .Where(photo => photo.AccommodationId == accommodationId)
            .OrderBy(photo => photo.DisplayOrder)
            .ThenBy(photo => photo.Id);

    private async Task<AccommodationPhotoResponse> ReadAsync(
        int accommodationId,
        int photoId,
        CancellationToken cancellationToken) =>
        await Of(accommodationId, photoId)
            .AsNoTracking()
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(photoId);

    private static NotFoundException Missing(int photoId) =>
        new($"No photo has the id {photoId}.");
}
