using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Validation;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class NewsWritingTests(DatabaseFixture fixture)
{
    private readonly NewsWorkspace workspace = new(fixture);

    [Fact]
    public async Task WhatIsPublishedCarriesTheAccountThatWroteIt()
    {
        var administrator = await workspace.AnAdministratorAsync();

        var written = await workspace.WriteAsync(
            administrator, title: "  A title  ", body: "  The text under it.  ");

        Assert.Equal("A title", written.Title);
        Assert.Equal("The text under it.", written.Body);
        Assert.Equal(administrator, written.AuthorId);
        Assert.Equal(ImageRules.Jpeg, written.ImageContentType);
        Assert.Null(written.ModifiedAt);
        Assert.True(written.PublishedAt <= DateTime.UtcNow);
    }

    [Fact]
    public async Task ThePictureIsStoredUnderTheTypeItsOwnBytesSay()
    {
        var administrator = await workspace.AnAdministratorAsync();

        var written = await workspace.WriteAsync(
            administrator, image: NewsWorkspace.Png, contentType: ImageRules.Unknown);

        var image = await workspace.ReadImageAsync(
            administrator, RoleNames.Administrator, written.Id);

        Assert.Equal(ImageRules.Png, written.ImageContentType);
        Assert.Equal(ImageRules.Png, image.ContentType);
        Assert.Equal(NewsWorkspace.Png, image.Content);
    }

    [Fact]
    public async Task AFileThatIsNoPictureIsRefusedUnderTheFieldThatCarriedIt()
    {
        var administrator = await workspace.AnAdministratorAsync();

        var failure = await Assert.ThrowsAsync<ValidationException>(
            () => workspace.WriteAsync(administrator, image: [0x25, 0x50, 0x44, 0x46]));

        Assert.Contains("File", failure.Errors.Keys);
    }

    [Fact]
    public async Task ATypeTheBytesDenyIsRefusedRatherThanStored()
    {
        var administrator = await workspace.AnAdministratorAsync();

        var failure = await Assert.ThrowsAsync<ValidationException>(
            () => workspace.WriteAsync(
                administrator, image: NewsWorkspace.Jpeg, contentType: ImageRules.Png));

        Assert.Contains("File", failure.Errors.Keys);
    }

    [Fact]
    public async Task AnEditKeepsThePictureItWasPublishedWith()
    {
        var administrator = await workspace.AnAdministratorAsync();
        var written = await workspace.WriteAsync(administrator);

        var edited = await workspace.UpdateAsync(
            administrator, written.Id, title: "A corrected title");

        var image = await workspace.ReadImageAsync(
            administrator, RoleNames.Administrator, written.Id);

        Assert.Equal("A corrected title", edited.Title);
        Assert.Equal(written.PublishedAt, edited.PublishedAt);
        Assert.NotNull(edited.ModifiedAt);
        Assert.Equal(ImageRules.Jpeg, image.ContentType);
        Assert.Equal(NewsWorkspace.Jpeg, image.Content);
    }

    [Fact]
    public async Task AnEditThatCarriesAPictureReplacesTheOneThatStood()
    {
        var administrator = await workspace.AnAdministratorAsync();
        var written = await workspace.WriteAsync(administrator);

        var edited = await workspace.UpdateAsync(
            administrator, written.Id, image: NewsWorkspace.Png);

        var image = await workspace.ReadImageAsync(
            administrator, RoleNames.Administrator, written.Id);

        Assert.Equal(ImageRules.Png, edited.ImageContentType);
        Assert.Equal(ImageRules.Png, image.ContentType);
        Assert.Equal(NewsWorkspace.Png, image.Content);
    }

    [Fact]
    public async Task AnEditThatCarriesNoPictureAtAllIsRefusedWithTheTextUnchanged()
    {
        var administrator = await workspace.AnAdministratorAsync();
        var written = await workspace.WriteAsync(administrator, title: "The title as it stands");

        await Assert.ThrowsAsync<ValidationException>(
            () => workspace.UpdateAsync(administrator, written.Id, image: []));

        var read = await workspace.ReadAsync(
            administrator, RoleNames.Administrator, written.Id);

        Assert.Equal("The title as it stands", read.Title);
        Assert.Null(read.ModifiedAt);
    }

    [Fact]
    public async Task AnIdNothingWasPublishedUnderIsNotFound()
    {
        var administrator = await workspace.AnAdministratorAsync();

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.UpdateAsync(administrator, int.MaxValue));

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.DeleteAsync(administrator, int.MaxValue));
    }

    [Fact]
    public async Task TakingOneDownLeavesNothingToRead()
    {
        var administrator = await workspace.AnAdministratorAsync();
        var written = await workspace.WriteAsync(administrator);

        await workspace.DeleteAsync(administrator, written.Id);

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(administrator, RoleNames.Administrator, written.Id));
    }
}
