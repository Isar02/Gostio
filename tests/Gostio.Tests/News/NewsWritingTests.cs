using System.Net;
using System.Net.Http.Headers;
using Gostio.API.Controllers;
using Gostio.Model.Authorization;
using Gostio.Model.Validation;
using Gostio.Services.News;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.News;

public sealed class NewsWritingTests : IAsyncLifetime
{
    private const string Route = "/api/news";

    private readonly StubNews news = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(services => services.AddSingleton<INewsService>(news));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(RoleNames.Guest, "POST", Route)]
    [InlineData(RoleNames.Guest, "PUT", $"{Route}/3")]
    [InlineData(RoleNames.Guest, "DELETE", $"{Route}/3")]
    [InlineData(RoleNames.Host, "POST", Route)]
    [InlineData(RoleNames.Host, "PUT", $"{Route}/3")]
    [InlineData(RoleNames.Host, "DELETE", $"{Route}/3")]
    public async Task WritingIsClosedToEverybodyButAnAdministrator(
        string role,
        string method,
        string path)
    {
        var response = await host.SendAsync(new HttpMethod(method), path, role, Upload());

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [InlineData("POST", Route, HttpStatusCode.Created)]
    [InlineData("PUT", $"{Route}/3", HttpStatusCode.OK)]
    [InlineData("DELETE", $"{Route}/3", HttpStatusCode.NoContent)]
    public async Task AnAdministratorReachesTheWrites(
        string method,
        string path,
        HttpStatusCode expected)
    {
        var response = await host.SendAsync(
            new HttpMethod(method), path, RoleNames.Administrator, Upload());

        Assert.Equal(expected, response.StatusCode);
    }

    [Fact]
    public async Task TheTextAndTheBytesReachTheServiceWhole()
    {
        await host.SendAsync(HttpMethod.Post, Route, RoleNames.Administrator, Upload());

        Assert.Equal("A title", news.LastRequest!.Title);
        Assert.Equal("The text under it.", news.LastRequest.Body);
        Assert.Equal(StubNews.Bytes, news.LastImage!.Content);
        Assert.Equal(ImageRules.Jpeg, news.LastImage.ContentType);
    }

    [Fact]
    public async Task PublishingWithoutAPictureIsRefused()
    {
        var response = await host.SendAsync(
            HttpMethod.Post, Route, RoleNames.Administrator, Upload(withFile: false));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Null(news.LastRequest);
    }

    [Fact]
    public async Task AnEditWithoutAPictureHandsTheServiceNone()
    {
        var response = await host.SendAsync(
            HttpMethod.Put, $"{Route}/3", RoleNames.Administrator, Upload(withFile: false));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(3, news.LastEdited);
        Assert.Null(news.LastImage);
    }

    [Fact]
    public async Task TakingOneDownNamesTheOneInThePath()
    {
        await host.SendAsync(HttpMethod.Delete, $"{Route}/9", RoleNames.Administrator);

        Assert.Equal(9, news.LastDeleted);
    }

    [Fact]
    public async Task ATitleLongerThanItsColumnIsRefused()
    {
        var response = await host.SendAsync(
            HttpMethod.Post,
            Route,
            RoleNames.Administrator,
            Upload(title: new string('x', ColumnLengths.Title + 1)));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Null(news.LastRequest);
    }

    [Fact]
    public async Task TheCeilingClearsTheHeaviestFormThatCanBeSent()
    {
        using var form = LargestUpload();

        var weight = (await form.ReadAsByteArrayAsync()).LongLength;

        Assert.True(
            weight <= UploadLimits.Multipart,
            $"A form weighing {weight} bytes meets a ceiling of {UploadLimits.Multipart}.");
    }

    private static MultipartFormDataContent Upload(string title = "A title", bool withFile = true)
    {
        var form = new MultipartFormDataContent
        {
            { new StringContent(title), "Title" },
            { new StringContent("The text under it."), "Body" },
        };

        if (withFile)
        {
            var file = new ByteArrayContent(StubNews.Bytes);

            file.Headers.ContentType = new MediaTypeHeaderValue(ImageRules.Jpeg);

            form.Add(file, "File", "news.jpg");
        }

        return form;
    }

    // Every column at its limit in a three-byte script, beside an image at the
    // largest a stored picture may be. In ASCII the same form weighs a third of
    // this and proves nothing.
    private static MultipartFormDataContent LargestUpload()
    {
        var image = new byte[ImageRules.MaximumBytes];

        image[0] = 0xFF;
        image[1] = 0xD8;
        image[2] = 0xFF;

        var file = new ByteArrayContent(image);

        file.Headers.ContentType = new MediaTypeHeaderValue(ImageRules.Jpeg);

        return new MultipartFormDataContent
        {
            { new StringContent(new string('€', ColumnLengths.Title)), "Title" },
            { new StringContent(new string('€', ColumnLengths.NewsBody)), "Body" },
            { file, "File", "news.jpg" },
        };
    }
}
