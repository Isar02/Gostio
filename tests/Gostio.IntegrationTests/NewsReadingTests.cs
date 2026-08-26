using Gostio.Model.Authorization;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Validation;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class NewsReadingTests(DatabaseFixture fixture)
{
    private readonly NewsWorkspace workspace = new(fixture);

    [Fact]
    public async Task WhatStandsIsReadBackWithTheAccountThatWroteIt()
    {
        var administrator = await workspace.AnAdministratorAsync();
        var published = DateTime.UtcNow.AddDays(-3);

        var id = await workspace.APublishedAsync(
            administrator, title: "A title", body: "The text under it.", publishedAt: published);

        var read = await workspace.ReadAsync(administrator, RoleNames.Guest, id);

        Assert.Equal("A title", read.Title);
        Assert.Equal("The text under it.", read.Body);
        Assert.Equal(administrator, read.AuthorId);
        Assert.Equal("Integration Tests", read.AuthorName);
        Assert.Equal(ImageRules.Jpeg, read.ImageContentType);
        Assert.Equal(published, read.PublishedAt, TimeSpan.FromSeconds(1));
        Assert.Null(read.ModifiedAt);
    }

    [Fact]
    public async Task ThePictureComesBackUnderTheTypeItIsStoredWith()
    {
        var administrator = await workspace.AnAdministratorAsync();

        var id = await workspace.APublishedAsync(
            administrator, image: NewsWorkspace.Png, contentType: ImageRules.Png);

        var image = await workspace.ReadImageAsync(administrator, RoleNames.Guest, id);

        Assert.Equal(ImageRules.Png, image.ContentType);
        Assert.Equal(NewsWorkspace.Png, image.Content);
    }

    [Fact]
    public async Task AnIdNothingWasPublishedUnderIsNotFound()
    {
        var administrator = await workspace.AnAdministratorAsync();

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadAsync(administrator, RoleNames.Guest, int.MaxValue));

        await Assert.ThrowsAsync<NotFoundException>(
            () => workspace.ReadImageAsync(administrator, RoleNames.Guest, int.MaxValue));
    }

    [Fact]
    public async Task TheListPutsTheNewestFirst()
    {
        var administrator = await workspace.AnAdministratorAsync();
        var marker = $"order-{Guid.NewGuid():N}";

        var older = await workspace.APublishedAsync(
            administrator, title: $"{marker} older", publishedAt: DateTime.UtcNow.AddDays(-2));

        var newer = await workspace.APublishedAsync(
            administrator, title: $"{marker} newer", publishedAt: DateTime.UtcNow.AddDays(-1));

        var page = await workspace.SearchAsync(
            administrator, RoleNames.Guest, new NewsSearchRequest { Title = marker });

        Assert.Equal([newer, older], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task TheListNarrowsByWhatTheTitleCarries()
    {
        var administrator = await workspace.AnAdministratorAsync();
        var marker = $"title-{Guid.NewGuid():N}";

        var wanted = await workspace.APublishedAsync(administrator, title: $"{marker} wanted");

        await workspace.APublishedAsync(administrator, title: $"{marker} other");

        var page = await workspace.SearchAsync(
            administrator,
            RoleNames.Guest,
            new NewsSearchRequest { Title = $"  {marker} wanted  " });

        Assert.Equal([wanted], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task TheListNarrowsByTheWindowItWasPublishedIn()
    {
        var administrator = await workspace.AnAdministratorAsync();
        var marker = $"window-{Guid.NewGuid():N}";

        var inside = await workspace.APublishedAsync(
            administrator, title: $"{marker} inside", publishedAt: DateTime.UtcNow.AddDays(-5));

        await workspace.APublishedAsync(
            administrator, title: $"{marker} outside", publishedAt: DateTime.UtcNow.AddDays(-30));

        var page = await workspace.SearchAsync(
            administrator,
            RoleNames.Guest,
            new NewsSearchRequest
            {
                Title = marker,
                PublishedFrom = DateTime.UtcNow.AddDays(-10),
                PublishedTo = DateTime.UtcNow,
            });

        Assert.Equal([inside], page.Items.Select(item => item.Id));
        Assert.Equal(1, page.TotalCount);
    }
}
