using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Database.Entities;
using Gostio.Services.News;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

internal sealed class NewsWorkspace(DatabaseFixture fixture)
{
    private const string Password = "the-newsroom-password";

    public static byte[] Jpeg =>
        [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46];

    public static byte[] Png =>
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D];

    public Task<int> AnAdministratorAsync() =>
        fixture.AddUserAsync(Password, RoleNames.Administrator);

    // Written to the table rather than through the endpoint that publishes one,
    // so what a read answers is never held up by what a write does, and a list
    // ordered by the moment it went out gets rows from more than one second.
    public async Task<int> APublishedAsync(
        int author,
        string title = "A title worth reading",
        string body = "The text that sits under it.",
        byte[]? image = null,
        string contentType = ImageRules.Jpeg,
        DateTime? publishedAt = null)
    {
        await using var db = fixture.CreateContext();

        var item = new NewsItem
        {
            CreatedByUserId = author,
            Title = title,
            Body = body,
            Image = image ?? Jpeg,
            ImageContentType = contentType,
            PublishedAt = publishedAt ?? DateTime.UtcNow,
        };

        db.News.Add(item);

        await db.SaveChangesAsync();

        return item.Id;
    }

    public Task<NewsResponse> ReadAsync(int actor, string role, int id) =>
        AsAsync(actor, role, service => service.GetAsync(id, default));

    public Task<ImageContent> ReadImageAsync(int actor, string role, int id) =>
        AsAsync(actor, role, service => service.GetImageAsync(id, default));

    public Task<PagedResult<NewsResponse>> SearchAsync(
        int actor,
        string role,
        NewsSearchRequest search) =>
        AsAsync(actor, role, service => service.SearchAsync(search, default));

    public Task<NewsResponse> WriteAsync(
        int actor,
        string title = "A title worth reading",
        string body = "The text that sits under it.",
        byte[]? image = null,
        string? contentType = null,
        string role = RoleNames.Administrator) =>
        AsAsync(
            actor,
            role,
            service => service.WriteAsync(
                Upsert(title, body),
                new ImageUpload(image ?? Jpeg, contentType),
                default));

    public Task<NewsResponse> UpdateAsync(
        int actor,
        int id,
        string title = "A title that was corrected",
        string body = "The text that was corrected with it.",
        byte[]? image = null,
        string? contentType = null,
        string role = RoleNames.Administrator) =>
        AsAsync(
            actor,
            role,
            service => service.UpdateAsync(
                id,
                Upsert(title, body),
                image is null ? null : new ImageUpload(image, contentType),
                default));

    public Task DeleteAsync(int actor, int id, string role = RoleNames.Administrator) =>
        AsAsync(
            actor,
            role,
            async service =>
            {
                await service.DeleteAsync(id, default);

                return true;
            });

    private static NewsUpsertRequest Upsert(string title, string body) =>
        new() { Title = title, Body = body };

    private async Task<TResult> AsAsync<TResult>(
        int actor,
        string role,
        Func<INewsService, Task<TResult>> work)
    {
        await using var services = fixture.BuildServices(ListingWorkspace.Caller(actor, role));

        return await work(services.GetRequiredService<INewsService>());
    }
}
