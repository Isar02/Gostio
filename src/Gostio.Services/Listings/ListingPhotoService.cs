using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Listings;

internal abstract class ListingPhotoService<TListing, TPhoto>(
    GostioDbContext db,
    ListingAccess<TListing> access)
    : IListingPhotoService
    where TListing : class, IListing
    where TPhoto : class, IListingPhoto
{
    private const string FileField = "File";

    protected ListingAccess<TListing> Access { get; } = access;

    protected DbSet<TPhoto> Photos => db.Set<TPhoto>();

    protected abstract Expression<Func<TPhoto, ListingPhotoResponse>> Projection { get; }

    protected abstract Expression<Func<TPhoto, bool>> Owned(int listingId);

    // Written where the foreign key has a name: the gate has to correlate with
    // the photo row, and no member of IListingPhoto carries the listing it
    // hangs off.
    protected abstract IQueryable<TPhoto> Visible(IQueryable<TPhoto> photos);

    protected abstract TPhoto NewPhoto(int listingId);

    public async Task<PagedResult<ListingPhotoResponse>> SearchAsync(
        int listingId,
        PagedRequest request,
        CancellationToken cancellationToken)
    {
        var page = await VisiblePhotos(listingId)
            .ToPagedResultAsync(request, Projection, cancellationToken);

        // The rows, not the count: a page is read with two statements, and a
        // listing withdrawn between them leaves a count the second one no longer
        // agrees with.
        if (page.Items.Count == 0)
        {
            await Access.RequireVisibleAsync(listingId, cancellationToken);
        }

        return page;
    }

    public async Task<ListingPhotoResponse> GetAsync(
        int listingId,
        int photoId,
        CancellationToken cancellationToken) =>
        await VisiblePhoto(listingId, photoId)
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? await MissingPhotoOrListingAsync<ListingPhotoResponse>(
            listingId, photoId, cancellationToken);

    public async Task<ImageContent> GetContentAsync(
        int listingId,
        int photoId,
        CancellationToken cancellationToken) =>
        await VisiblePhoto(listingId, photoId)
            .Select(photo => new ImageContent(photo.Image, photo.ContentType))
            .FirstOrDefaultAsync(cancellationToken)
        ?? await MissingPhotoOrListingAsync<ImageContent>(listingId, photoId, cancellationToken);

    public async Task<ListingPhotoResponse> AddAsync(
        int listingId,
        ImageUpload upload,
        CancellationToken cancellationToken)
    {
        await Access.RequireOwnedAsync(listingId, cancellationToken);

        var contentType = RequireImage(upload);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await Access.LockAsync(listingId, cancellationToken);

        var listingPhotos = Photos.Where(Owned(listingId));

        var highest = await listingPhotos.MaxAsync(
            photo => (int?)photo.DisplayOrder, cancellationToken);

        var covered = await listingPhotos.AnyAsync(photo => photo.IsCover, cancellationToken);

        var photo = NewPhoto(listingId);

        photo.Image = upload.Content;
        photo.ContentType = contentType;
        photo.IsCover = !covered;
        photo.DisplayOrder = (highest ?? -1) + 1;
        photo.UploadedAt = DateTime.UtcNow;

        Photos.Add(photo);

        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        return await ReadAsync(listingId, photo.Id, cancellationToken);
    }

    public async Task<ListingPhotoResponse> SetCoverAsync(
        int listingId,
        int photoId,
        CancellationToken cancellationToken)
    {
        await Access.RequireOwnedAsync(listingId, cancellationToken);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await Access.LockAsync(listingId, cancellationToken);

        // Cleared before the new one is set: one cover per listing is a unique
        // index, and the other order collides with it.
        await Photos
            .Where(Owned(listingId))
            .Where(photo => photo.IsCover)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(photo => photo.IsCover, false),
                cancellationToken);

        var promoted = await ForPhoto(listingId, photoId)
            .ExecuteUpdateAsync(
                setters => setters.SetProperty(photo => photo.IsCover, true),
                cancellationToken);

        if (promoted == 0)
        {
            throw Missing(photoId);
        }

        await transaction.CommitAsync(cancellationToken);

        return await ReadAsync(listingId, photoId, cancellationToken);
    }

    public async Task DeleteAsync(int listingId, int photoId, CancellationToken cancellationToken)
    {
        await Access.RequireOwnedAsync(listingId, cancellationToken);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);

        await Access.LockAsync(listingId, cancellationToken);

        var wasCover = await ForPhoto(listingId, photoId)
            .AsNoTracking()
            .Select(photo => (bool?)photo.IsCover)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw Missing(photoId);

        await ForPhoto(listingId, photoId).ExecuteDeleteAsync(cancellationToken);

        if (wasCover)
        {
            await PromoteNextAsync(listingId, cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
    }

    private async Task PromoteNextAsync(int listingId, CancellationToken cancellationToken)
    {
        var next = await VisiblePhotos(listingId)
            .Select(photo => (int?)photo.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (next is int id)
        {
            await Photos
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

    private IQueryable<TPhoto> ForPhoto(int listingId, int photoId) =>
        Photos.Where(Owned(listingId)).Where(photo => photo.Id == photoId);

    private IQueryable<TPhoto> VisiblePhoto(int listingId, int photoId) =>
        Visible(ForPhoto(listingId, photoId).AsNoTracking());

    private IOrderedQueryable<TPhoto> VisiblePhotos(int listingId) =>
        Visible(Photos.AsNoTracking().Where(Owned(listingId)))
            .OrderBy(photo => photo.DisplayOrder)
            .ThenBy(photo => photo.Id);

    private async Task<T> MissingPhotoOrListingAsync<T>(
        int listingId,
        int photoId,
        CancellationToken cancellationToken)
    {
        await Access.RequireVisibleAsync(listingId, cancellationToken);

        throw Missing(photoId);
    }

    private async Task<ListingPhotoResponse> ReadAsync(
        int listingId,
        int photoId,
        CancellationToken cancellationToken) =>
        await ForPhoto(listingId, photoId)
            .AsNoTracking()
            .Select(Projection)
            .FirstOrDefaultAsync(cancellationToken)
        ?? throw Missing(photoId);

    private static NotFoundException Missing(int photoId) =>
        new($"No photo has the id {photoId}.");
}
