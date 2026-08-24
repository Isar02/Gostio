using System.Net;
using System.Net.Http.Headers;
using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Listings;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Listings;

// The shared base is what the accommodation suite exercises. What is only true
// here is the route these actions hang off and the service behind it.
public sealed class ExperiencePhotosControllerTests : IAsyncLifetime
{
    private const string Route = "/api/experiences/7/photos";

    private readonly StubPhotos photos = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IExperiencePhotoService>(photos));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(Route)]
    [InlineData($"{Route}/3")]
    [InlineData($"{Route}/3/content")]
    public async Task ReadingIsOpenToAnySignedInAccount(string path)
    {
        var response = await host.SendAsync(HttpMethod.Get, path, RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
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
    public async Task TheExperienceInTheRouteReachesTheService()
    {
        await host.SendAsync(HttpMethod.Post, Route, RoleNames.Host, Upload());

        Assert.Equal(7, photos.LastListingId);
        Assert.Equal(StubPhotos.Bytes, photos.LastUpload!.Content);
    }

    [Fact]
    public async Task NoneOfItIsReachableWithoutAToken()
    {
        var response = await host.SendAsync(HttpMethod.Get, Route);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private static HttpContent? BodyFor(string method) =>
        method == "POST" ? Upload() : null;

    private static MultipartFormDataContent Upload()
    {
        var file = new ByteArrayContent(StubPhotos.Bytes);

        file.Headers.ContentType = new MediaTypeHeaderValue(ImageRules.Jpeg);

        return new MultipartFormDataContent { { file, "File", "photo.jpg" } };
    }

    private sealed class StubPhotos : IExperiencePhotoService
    {
        public static byte[] Bytes => [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];

        public ImageUpload? LastUpload { get; private set; }

        public int? LastListingId { get; private set; }

        public Task<PagedResult<ListingPhotoResponse>> SearchAsync(
            int listingId,
            PagedRequest request,
            CancellationToken cancellationToken) =>
            Task.FromResult(new PagedResult<ListingPhotoResponse>
            {
                Items = [Row(1)],
                Page = request.Page,
                PageSize = request.PageSize,
                TotalCount = 1,
            });

        public Task<ListingPhotoResponse> GetAsync(
            int listingId,
            int photoId,
            CancellationToken cancellationToken) => Task.FromResult(Row(photoId));

        public Task<ImageContent> GetContentAsync(
            int listingId,
            int photoId,
            CancellationToken cancellationToken) =>
            Task.FromResult(new ImageContent(Bytes, ImageRules.Jpeg));

        public Task<ListingPhotoResponse> AddAsync(
            int listingId,
            ImageUpload upload,
            CancellationToken cancellationToken)
        {
            LastListingId = listingId;
            LastUpload = upload;

            return Task.FromResult(Row(9));
        }

        public Task<ListingPhotoResponse> SetCoverAsync(
            int listingId,
            int photoId,
            CancellationToken cancellationToken) => Task.FromResult(Row(photoId));

        public Task DeleteAsync(
            int listingId,
            int photoId,
            CancellationToken cancellationToken) => Task.CompletedTask;

        private static ListingPhotoResponse Row(int id) => new()
        {
            Id = id,
            ListingId = 7,
            ContentType = ImageRules.Jpeg,
            IsCover = true,
            DisplayOrder = 0,
            SizeInBytes = Bytes.Length,
            UploadedAt = DateTime.UtcNow,
        };
    }
}
