using System.Net;
using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.HostVerification;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.HostVerification;

public sealed class HostVerificationRequestsControllerTests : IAsyncLifetime
{
    private const string Route = "/api/host-verification-requests";

    private readonly StubHostVerification requests = new();

    private ApiHost host = null!;

    public async Task InitializeAsync() =>
        host = await ApiHost.StartAsync(
            services => services.AddSingleton<IHostVerificationService>(requests));

    public async Task DisposeAsync() => await host.DisposeAsync();

    [Theory]
    [InlineData(RoleNames.Guest)]
    [InlineData(RoleNames.Host)]
    [InlineData(RoleNames.Administrator)]
    public async Task TheListIsOpenToAnySignedInAccount(string role)
    {
        var response = await host.SendAsync(HttpMethod.Get, Route, role);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task TheListCarriesItsFiltersThrough()
    {
        var response = await host.SendAsync(
            HttpMethod.Get,
            $"{Route}?status=Pending&userId=7&pageSize=5",
            RoleNames.Administrator);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(HostVerificationStatus.Pending, requests.LastSearch?.Status);
        Assert.Equal(7, requests.LastSearch?.UserId);
        Assert.Equal(5, requests.LastSearch?.PageSize);
    }

    [Fact]
    public async Task ApplyingAnswersWhereItCanBeReadBack()
    {
        var response = await host.SendAsync(HttpMethod.Post, Route, RoleNames.Guest);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.Equal(
            $"{Route}/{StubHostVerification.Applied}", response.Headers.Location?.AbsolutePath);
        Assert.True(requests.HasApplied);
    }

    [Fact]
    public async Task ReadingOneNamesTheRequestItWasAskedFor()
    {
        var response = await host.SendAsync(HttpMethod.Get, $"{Route}/9", RoleNames.Guest);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(9, requests.LastRead);
    }

    [Theory]
    [InlineData("GET", Route)]
    [InlineData("POST", Route)]
    [InlineData("GET", $"{Route}/9")]
    public async Task NoneOfItIsReachableWithoutAToken(string method, string path)
    {
        var response = await host.SendAsync(new HttpMethod(method), path);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private sealed class StubHostVerification : IHostVerificationService
    {
        public const int Applied = 12;

        public HostVerificationSearchRequest? LastSearch { get; private set; }

        public int? LastRead { get; private set; }

        public bool HasApplied { get; private set; }

        public Task<PagedResult<HostVerificationRequestResponse>> SearchAsync(
            HostVerificationSearchRequest search,
            CancellationToken cancellationToken)
        {
            LastSearch = search;

            return Task.FromResult(new PagedResult<HostVerificationRequestResponse>
            {
                Items = [Row(1)],
                Page = search.Page,
                PageSize = search.PageSize,
                TotalCount = 1,
            });
        }

        public Task<HostVerificationRequestResponse> GetAsync(
            int id,
            CancellationToken cancellationToken)
        {
            LastRead = id;

            return Task.FromResult(Row(id));
        }

        public Task<HostVerificationRequestResponse> ApplyAsync(
            CancellationToken cancellationToken)
        {
            HasApplied = true;

            return Task.FromResult(Row(Applied));
        }

        private static HostVerificationRequestResponse Row(int id) => new()
        {
            Id = id,
            UserId = 42,
            Username = "probe",
            ApplicantName = "A Guest",
            Status = nameof(HostVerificationStatus.Pending),
            SubmittedAt = new DateTime(2026, 8, 25, 9, 0, 0, DateTimeKind.Utc),
        };
    }
}
