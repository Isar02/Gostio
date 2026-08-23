using System.Net;
using System.Net.Http.Headers;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Listings;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Listings;

// The photos follow the listing: anybody signed in may look, and only a host or
// an administrator may write. Which listing is theirs is left to the service.
public sealed class AccommodationPhotosControllerTests : IAsyncLifetime
{
    private const string Route = "/api/accommodations/7/photos";

    private readonly StubPhotos photos = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IAccommodationPhotoService>(photos));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(Route)]
    [InlineData($"{Route}/3")]
    public async Task ReadingIsOpenToAnySignedInAccount(string path)
    {
        var response = await host.SendAsync(HttpMethod.Get, path, RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task TheImageComesBackUnderTheTypeItIsStoredWith()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, $"{Route}/3/content", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(ImageRules.Jpeg, response.Content.Headers.ContentType!.MediaType);
        Assert.Equal(StubPhotos.Bytes, await response.Content.ReadAsByteArrayAsync());
    }

    [Theory]
    [InlineData("POST", Route)]
    [InlineData("PUT", $"{Route}/3/cover")]
    [InlineData("DELETE", $"{Route}/3")]
    public async Task WritingIsClosedToAGuest(string method, string path)
    {
        var response = await host.SendAsync(
            new HttpMethod(method), path, RoleNames.Guest, BodyFor(method));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [InlineData(RoleNames.Host, "POST", Route, HttpStatusCode.Created)]
    [InlineData(RoleNames.Host, "PUT", $"{Route}/3/cover", HttpStatusCode.OK)]
    [InlineData(RoleNames.Host, "DELETE", $"{Route}/3", HttpStatusCode.NoContent)]
    [InlineData(RoleNames.Administrator, "POST", Route, HttpStatusCode.Created)]
    [InlineData(RoleNames.Administrator, "PUT", $"{Route}/3/cover", HttpStatusCode.OK)]
    [InlineData(RoleNames.Administrator, "DELETE", $"{Route}/3", HttpStatusCode.NoContent)]
    public async Task AHostAndAnAdministratorBothReachTheWrites(
        string role,
        string method,
        string path,
        HttpStatusCode expected)
    {
        var response = await host.SendAsync(
            new HttpMethod(method), path, role, BodyFor(method));

        Assert.Equal(expected, response.StatusCode);
    }

    [Fact]
    public async Task AnUploadCarryingNoFileIsRefused()
    {
        var response = await host.SendAsync(
            HttpMethod.Post, Route, RoleNames.Host, new MultipartFormDataContent());

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task TheUploadedBytesReachTheServiceWhole()
    {
        await host.SendAsync(HttpMethod.Post, Route, RoleNames.Host, Upload());

        Assert.Equal(StubPhotos.Bytes, photos.LastUpload!.Content);
        Assert.Equal(ImageRules.Jpeg, photos.LastUpload.ContentType);
        Assert.Equal(7, photos.LastAccommodationId);
    }

    [Fact]
    public async Task NoneOfItIsReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, Route);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task TheQueryStringReachesThePageThroughItsBounds()
    {
        var response = await host.SendAsync(
            HttpMethod.Get, $"{Route}?page=0&pageSize=5000", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(1, photos.LastPage!.Page);
        Assert.Equal(PagedRequest.MaxPageSize, photos.LastPage.PageSize);
    }

    private static HttpContent? BodyFor(string method) =>
        method == "POST" ? Upload() : null;

    private static MultipartFormDataContent Upload()
    {
        var file = new ByteArrayContent(StubPhotos.Bytes);

        file.Headers.ContentType = new MediaTypeHeaderValue(ImageRules.Jpeg);

        return new MultipartFormDataContent { { file, "File", "photo.jpg" } };
    }

    private sealed class StubPhotos : IAccommodationPhotoService
    {
        public static byte[] Bytes => [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];

        public PagedRequest? LastPage { get; private set; }

        public ImageUpload? LastUpload { get; private set; }

        public int? LastAccommodationId { get; private set; }

        public Task<PagedResult<AccommodationPhotoResponse>> SearchAsync(
            int accommodationId,
            PagedRequest request,
            CancellationToken cancellationToken)
        {
            LastPage = request;

            return Task.FromResult(new PagedResult<AccommodationPhotoResponse>
            {
                Items = [Row(1)],
                Page = request.Page,
                PageSize = request.PageSize,
                TotalCount = 1,
            });
        }

        public Task<AccommodationPhotoResponse> GetAsync(
            int accommodationId,
            int photoId,
            CancellationToken cancellationToken) => Task.FromResult(Row(photoId));

        public Task<ImageContent> GetContentAsync(
            int accommodationId,
            int photoId,
            CancellationToken cancellationToken) =>
            Task.FromResult(new ImageContent(Bytes, ImageRules.Jpeg));

        public Task<AccommodationPhotoResponse> AddAsync(
            int accommodationId,
            ImageUpload upload,
            CancellationToken cancellationToken)
        {
            LastAccommodationId = accommodationId;
            LastUpload = upload;

            return Task.FromResult(Row(9));
        }

        public Task<AccommodationPhotoResponse> SetCoverAsync(
            int accommodationId,
            int photoId,
            CancellationToken cancellationToken) => Task.FromResult(Row(photoId));

        public Task DeleteAsync(
            int accommodationId,
            int photoId,
            CancellationToken cancellationToken) => Task.CompletedTask;

        private static AccommodationPhotoResponse Row(int id) => new()
        {
            Id = id,
            AccommodationId = 7,
            ContentType = ImageRules.Jpeg,
            IsCover = true,
            DisplayOrder = 0,
            SizeInBytes = Bytes.Length,
            UploadedAt = DateTime.UtcNow,
        };
    }
}
