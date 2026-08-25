using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Favorites;
using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

internal sealed class FavoriteWorkspace(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-somebody-keeping-listings";

    private static readonly byte[] Jpeg =
        [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46];

    private readonly AccommodationWorkspace accommodations = new(fixture);

    private readonly ExperienceWorkspace experiences = new(fixture);

    public Task<(int Host, int Listing)> AnAccommodationAsync() =>
        accommodations.AListingAsync(Password);

    public Task<(int Host, int Listing)> AnExperienceAsync() =>
        experiences.AListingAsync(Password);

    public Task<int> AGuestAsync() => fixture.AddUserAsync(Password, RoleNames.Guest);

    public Task WithdrawAccommodationAsync(int host, int listing) =>
        accommodations.WithdrawAsync(host, listing);

    public Task WithdrawExperienceAsync(int host, int listing) =>
        experiences.WithdrawAsync(host, listing);

    public Task DeleteAccommodationAsync(int host, int listing) =>
        AsAsync(
            host,
            RoleNames.Host,
            async (IAccommodationService service) =>
            {
                await service.DeleteAsync(listing, default);

                return true;
            });

    public async Task<int> ACoverPhotoAsync(int host, int listing)
    {
        var photo = await AsAsync(
            host,
            RoleNames.Host,
            (IAccommodationPhotoService service) =>
                service.AddAsync(listing, new ImageUpload(Jpeg, null), default));

        return photo.Id;
    }

    public Task<FavoriteResponse> KeepAccommodationAsync(
        int actor,
        int listing,
        params IInterceptor[] interceptors) =>
        AsAsync(
            actor,
            RoleNames.Guest,
            (IAccommodationFavoriteService service) => service.AddAsync(listing, default),
            interceptors);

    public Task<FavoriteResponse> KeepExperienceAsync(int actor, int listing) =>
        AsAsync(
            actor,
            RoleNames.Guest,
            (IExperienceFavoriteService service) => service.AddAsync(listing, default));

    public Task DropAccommodationAsync(int actor, int listing) =>
        AsAsync(
            actor,
            RoleNames.Guest,
            async (IAccommodationFavoriteService service) =>
            {
                await service.RemoveAsync(listing, default);

                return true;
            });

    public Task DropExperienceAsync(int actor, int listing) =>
        AsAsync(
            actor,
            RoleNames.Guest,
            async (IExperienceFavoriteService service) =>
            {
                await service.RemoveAsync(listing, default);

                return true;
            });

    public Task<PagedResult<FavoriteResponse>> ListAsync(
        int actor,
        FavoriteSearchRequest? search = null) =>
        AsAsync(
            actor,
            RoleNames.Guest,
            (IFavoriteService service) => service.SearchAsync(search ?? new(), default));

    private async Task<TResult> AsAsync<TService, TResult>(
        int actor,
        string role,
        Func<TService, Task<TResult>> work,
        params IInterceptor[] interceptors)
        where TService : notnull
    {
        await using var services = fixture.BuildServices(
            ListingWorkspace.Caller(actor, role), interceptors);

        return await work(services.GetRequiredService<TService>());
    }
}
