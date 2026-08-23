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

        return await ForPhoto(accommodationId, photoId)
            .Select(photo => new ImageContent(photo.Image, photo.ContentType))
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw Missing(photoId);
    }

    public async Task<AccommodationPhotoResponse> AddAsync(
        int accommodationId,
        ImageUpload upload,
        CancellationToken cancellationToken)
    {
        await access.RequireOwnedAsync(accommodationId, cancellationToken);

        var contentType = RequireImage(upload);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await LockListingAsync(accommodationId, cancellationToken);

        var listingPhotos = db.AccommodationPhotos
            .Where(photo => photo.AccommodationId == accommodationId);

        var highest = await listingPhotos.MaxAsync(
            photo => (int?)photo.DisplayOrder, cancellationToken);

        var covered = await listingPhotos.AnyAsync(photo => photo.IsCover, cancellationToken);

        var photo = new AccommodationPhoto
        {
            AccommodationId = accommodationId,
            Image = upload.Content,
            ContentType = contentType,
            IsCover = !covered,
            DisplayOrder = (highest ?? -1) + 1,
            UploadedAt = DateTime.UtcNow,
        };

        db.AccommodationPhotos.Add(photo);

        await db.SaveChangesAsync(cancellationToken);
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

        await LockListingAsync(accommodationId, cancellationToken);

        // Cleared before the new one is set: one cover per listing is a unique
        // index, and the other order collides with it.
        await db.AccommodationPhotos
            .Where(photo => photo.AccommodationId == accommodationId && photo.IsCover)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(photo => photo.IsCover, false),
                cancellationToken);

        var promoted = await ForPhoto(accommodationId, photoId)
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

        await LockListingAsync(accommodationId, cancellationToken);

        var wasCover = await ForPhoto(accommodationId, photoId)
            .AsNoTracking()
            .Select(photo => (bool?)photo.IsCover)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw Missing(photoId);

        await ForPhoto(accommodationId, photoId).ExecuteDeleteAsync(cancellationToken);

        if (wasCover)
        {
            await PromoteNextAsync(accommodationId, cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
    }

    // One cover per listing is a unique index, and the database runs read
    // committed snapshot: two callers reading at once both find no cover, and
    // the second loses its upload to a duplicate key. This is what queues them.
    private Task LockListingAsync(int accommodationId, CancellationToken cancellationToken) =>
        db.Database.ExecuteSqlAsync(
            $"""
            SELECT TOP 1 1 FROM [Accommodations] WITH (UPDLOCK, HOLDLOCK)
            WHERE [Id] = {accommodationId}
            """,
            cancellationToken);

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

    private static string RequireImage(ImageUpload upload)
    {
        if (upload.Content.Length == 0)
        {
            throw new ValidationException(FileField, "Choose an image to upload.");
        }

        if (upload.Content.Length > ImageRules.MaximumBytes)
        {
            throw new ValidationException(
                FileField,
                $"An image is at most {ImageRules.MaximumBytes / (1024 * 1024)} MB.");
        }

        var detected = ImageRules.Detect(upload.Content)
            ?? throw new ValidationException(
                FileField,
                $"An image has to be one of {string.Join(", ", ImageRules.Allowed)}.");

        // The claim is checked and then dropped: what reaches the column is
        // what the bytes proved, so a stored type holds on the way back out.
        var claimed = Claimed(upload.ContentType);

        if (claimed is not null
            && !string.Equals(claimed, detected, StringComparison.OrdinalIgnoreCase))
        {
            throw new ValidationException(
                FileField, $"This file was sent as {claimed} and its bytes say {detected}.");
        }

        return detected;
    }

    private static string? Claimed(string? contentType)
    {
        var named = contentType?.Split(';')[0].Trim();

        return string.IsNullOrEmpty(named)
            || string.Equals(named, ImageRules.Unknown, StringComparison.OrdinalIgnoreCase)
                ? null
                : named;
    }

    private IQueryable<AccommodationPhoto> ForPhoto(int accommodationId, int photoId) =>
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
        await ForPhoto(accommodationId, photoId)
            .AsNoTracking()
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(photoId);

    private static NotFoundException Missing(int photoId) =>
        new($"No photo has the id {photoId}.");
}
