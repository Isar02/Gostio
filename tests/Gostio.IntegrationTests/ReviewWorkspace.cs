using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Gostio.Services.Reviews;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

internal sealed record CompletedStay(int Host, int Guest, int Booking, int Accommodation);

internal sealed record CompletedTerm(int Host, int Guest, int Booking, int Experience);

internal sealed class ReviewWorkspace(DatabaseFixture fixture)
{
    private static DateOnly Today => DateOnly.FromDateTime(DateTime.UtcNow);

    private readonly ReservationWorkspace reservations = new(fixture);

    public ReservationWorkspace Reservations => reservations;

    public async Task<CompletedStay> ACompletedStayAsync()
    {
        var (host, listing) = await reservations.AListingAsync();
        var guest = await reservations.AGuestAsync();
        var booked = await reservations.BookStayAsync(guest, listing, Today.AddDays(20), nights: 2);

        await reservations.ConfirmAsync(host, RoleNames.Host, booked.Id);
        await reservations.MoveTheStayAsync(booked.Id, Today);
        await reservations.SweepAsync();

        return new CompletedStay(host, guest, booked.Id, listing);
    }

    public async Task<CompletedTerm> ACompletedTermAsync(int? existingHost = null)
    {
        var startsAt = DateTime.UtcNow.AddDays(20);

        var (host, slot) = existingHost is int owner
            ? (owner, await ATermForAsync(owner, startsAt))
            : await reservations.ATermAsync(capacity: 4, startsAt: startsAt);

        var guest = await reservations.AGuestAsync();
        var booked = await reservations.BookTermAsync(guest, slot, guestCount: 1);

        await reservations.ConfirmAsync(host, RoleNames.Host, booked.Id);
        await reservations.StartTheTermAsync(slot, TimeSpan.FromHours(3));
        await reservations.SweepAsync();

        return new CompletedTerm(
            host, guest, booked.Id, await reservations.ExperienceOfAsync(slot));
    }

    public Task<ReviewResponse> WriteAsync(
        int actor,
        string role,
        int booking,
        int? rating = 5,
        string? comment = null,
        params IInterceptor[] interceptors) =>
        AsAsync(
            actor,
            role,
            (IReviewService service) =>
                service.WriteAsync(booking, Upsert(rating, comment), default),
            interceptors);

    public Task<ReviewResponse> UpdateAsync(
        int actor,
        string role,
        int booking,
        int? rating = 4,
        string? comment = null) =>
        AsAsync(
            actor,
            role,
            (IReviewService service) =>
                service.UpdateAsync(booking, Upsert(rating, comment), default));

    public Task<ReviewResponse> ReadAsync(int actor, string role, int booking) =>
        AsAsync(actor, role, (IReviewService service) => service.GetAsync(booking, default));

    public Task<PagedResult<ReviewResponse>> SearchAsync(
        int actor,
        string role,
        ReviewSearchRequest search) =>
        AsAsync(actor, role, (IReviewService service) => service.SearchAsync(search, default));

    public Task DeleteAsync(int actor, string role, int booking) =>
        AsAsync(
            actor,
            role,
            async (IReviewService service) =>
            {
                await service.DeleteAsync(booking, default);

                return true;
            });

    private async Task<int> ATermForAsync(int host, DateTime startsAt)
    {
        var experience = await reservations.AnExperienceWithoutTermsAsync(host);

        var slot = await AsAsync(
            host,
            RoleNames.Host,
            (IExperienceSlotService service) => service.AddAsync(
                experience,
                new ExperienceSlotCreateRequest { StartTime = startsAt, Capacity = 4 },
                default));

        return slot.Id;
    }

    private static ReviewUpsertRequest Upsert(int? rating, string? comment) =>
        new() { Rating = rating, Comment = comment };

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
