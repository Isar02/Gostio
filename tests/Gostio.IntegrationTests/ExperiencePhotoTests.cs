using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ExperiencePhotoTests(DatabaseFixture fixture)
    : ListingPhotoTests<IExperiencePhotoService>(fixture)
{
    private readonly ExperienceWorkspace workspace = new(fixture);

    protected override ListingWorkspace Workspace => workspace;

    protected override async Task<IReadOnlyList<(int Id, bool IsCover, int DisplayOrder)>>
        PhotosOfAsync(int listing)
    {
        await using var db = Fixture.CreateContext();

        var rows = await db.ExperiencePhotos
            .Where(photo => photo.ExperienceId == listing)
            .Select(photo => new { photo.Id, photo.IsCover, photo.DisplayOrder })
            .ToListAsync();

        return [.. rows.Select(row => (row.Id, row.IsCover, row.DisplayOrder))];
    }

    protected override async Task<int?> CoverOfListingAsync(int host, int listing)
    {
        var read = await Workspace.AsHostAsync(
            host, (IExperienceService experiences) => experiences.GetAsync(listing, default));

        return read.CoverPhotoId;
    }
}
