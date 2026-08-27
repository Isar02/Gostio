using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Gostio.Services.Favorites;
using Gostio.Services.Listings;
using Gostio.Services.Recommendations;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

internal sealed class RecommendationWorkspace(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-somebody-being-suggested-to";

    public Task<int> AGuestAsync() => fixture.AddUserAsync(Password, RoleNames.Guest);

    public Task<int> AHostAsync() => fixture.AddUserAsync(Password, RoleNames.Host);

    // A city name no other test writes a listing into.
    public Task<int> ACityOfItsOwnAsync() =>
        fixture.EnsureCityAsync($"Suggested {Guid.NewGuid():N}");

    public async Task<int> AnAccommodationAsync(int host, int city, decimal price = 100m)
    {
        var listing = ListingRequests.New(
            await AccommodationsInAsync(city), $"A place {Guid.NewGuid():N}", price: price);

        var created = await AsHostAsync(
            host, (IAccommodationService service) => service.CreateAsync(listing, default));

        return created.Id;
    }

    public async Task WithdrawAsync(int host, int listing, int city)
    {
        var withdrawn = ListingRequests.Edit(
            await AccommodationsInAsync(city), "Taken off the market", isActive: false);

        await AsHostAsync(
            host,
            (IAccommodationService service) =>
                service.UpdateAsync(listing, withdrawn, default));
    }

    public async Task<int> AnExperienceAsync(
        int host,
        int city,
        bool withTerm,
        int capacity = 4)
    {
        var references = new ExperienceReferences(
            city, await fixture.EnsureExperienceCategoryAsync("Walking tour"));

        var created = await AsHostAsync(
            host,
            (IExperienceService service) => service.CreateAsync(
                ExperienceRequests.New(references, $"A walk {Guid.NewGuid():N}"), default));

        if (withTerm)
        {
            var term = new ExperienceSlotCreateRequest
            {
                StartTime = DateTime.UtcNow.AddDays(10),
                Capacity = capacity,
            };

            await AsHostAsync(
                host,
                (IExperienceSlotService service) => service.AddAsync(created.Id, term, default));
        }

        return created.Id;
    }

    public Task SearchAccommodationsAsync(int actor, AccommodationSearchRequest search) =>
        AsAsync(
            Caller(actor, RoleNames.Guest),
            (IAccommodationService service) => service.SearchAsync(search, default));

    public Task SearchExperiencesAsync(int actor, ExperienceSearchRequest search) =>
        AsAsync(
            Caller(actor, RoleNames.Guest),
            (IExperienceService service) => service.SearchAsync(search, default));

    public Task KeepAsync(int actor, int listing) =>
        AsAsync(
            Caller(actor, RoleNames.Guest),
            (IAccommodationFavoriteService service) => service.AddAsync(listing, default));

    public Task<PagedResult<RecommendationResponse>> SuggestAsync(
        int actor,
        SearchTarget? target,
        string role = RoleNames.Guest,
        int pageSize = PagedRequest.DefaultPageSize,
        int page = 1) =>
        SuggestAsAsync(Caller(actor, role), target, pageSize, page);

    public async Task<IReadOnlyList<int>> AllSuggestedAsync(
        int actor,
        SearchTarget target,
        string role = RoleNames.Guest)
    {
        List<int> suggested = [];
        var page = 1;

        while (true)
        {
            var answer = await SuggestAsync(
                actor, target, role, PagedRequest.MaxPageSize, page);

            suggested.AddRange(answer.Items.Select(suggestion => suggestion.ListingId));

            if (answer.Items.Count == 0 || suggested.Count >= answer.TotalCount)
            {
                return suggested;
            }

            page++;
        }
    }

    public Task<PagedResult<RecommendationResponse>> SuggestToNobodyAsync() =>
        SuggestAsAsync(
            new AnonymousUser(), SearchTarget.Accommodations, PagedRequest.DefaultPageSize, 1);

    private Task<PagedResult<RecommendationResponse>> SuggestAsAsync(
        ICurrentUser caller,
        SearchTarget? target,
        int pageSize,
        int page) =>
        AsAsync(
            caller,
            (IRecommendationService service) => service.SearchAsync(
                new RecommendationSearchRequest
                {
                    Target = target,
                    PageSize = pageSize,
                    Page = page,
                },
                default));

    private async Task<ListingReferences> AccommodationsInAsync(int city) =>
        new(
            city,
            await fixture.EnsureAccommodationTypeAsync("Apartment"),
            await fixture.EnsureAccommodationCategoryAsync("City break"));

    private static ICurrentUser Caller(int actor, string role) =>
        ListingWorkspace.Caller(actor, role);

    private Task<TResult> AsHostAsync<TService, TResult>(
        int host,
        Func<TService, Task<TResult>> work)
        where TService : notnull =>
        AsAsync(Caller(host, RoleNames.Host), work);

    private async Task<TResult> AsAsync<TService, TResult>(
        ICurrentUser caller,
        Func<TService, Task<TResult>> work)
        where TService : notnull
    {
        await using var services = fixture.BuildServices(caller);

        return await work(services.GetRequiredService<TService>());
    }
}
