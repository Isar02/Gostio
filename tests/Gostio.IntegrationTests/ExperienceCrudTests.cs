using Gostio.Model.Authorization;
using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Services.Authentication;
using Gostio.Services.Database.Entities;
using Gostio.Services.Listings;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ExperienceCrudTests(DatabaseFixture fixture)
{
    private const string Password = "a-password-for-an-experience-owner";

    [Fact]
    public async Task AHostKeepsTheExperienceTheyCreate()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var created = await AsAsync(
            Caller(host, RoleNames.Host),
            experiences => experiences.CreateAsync(
                ExperienceRequests.New(references, "  A walk through the old town  "),
                CancellationToken.None));

        Assert.Equal(host, created.HostId);
        Assert.True(created.IsActive);
        Assert.Equal("A walk through the old town", created.Title);
        Assert.Equal("Sarajevo", created.CityName);
        Assert.Equal("Bosnia and Herzegovina", created.CountryName);
        Assert.Equal("Walking tour", created.ExperienceCategoryName);
    }

    [Fact]
    public async Task AnAdministratorCreatesAnExperienceForANamedHost()
    {
        var administrator = await fixture.AddUserAsync(Password, RoleNames.Administrator);
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var created = await AsAsync(
            Caller(administrator, RoleNames.Administrator),
            experiences => experiences.CreateAsync(
                ExperienceRequests.New(references, "A morning on the river", hostId: host),
                CancellationToken.None));

        Assert.Equal(host, created.HostId);
    }

    [Fact]
    public async Task AnAccountThatHostsNothingCannotKeepAnExperience()
    {
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var references = await ReferencesAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsAsync(
            Caller(guest, RoleNames.Guest),
            experiences => experiences.CreateAsync(
                ExperienceRequests.New(references, "A tour a guest cannot run"),
                CancellationToken.None)));

        Assert.Contains(nameof(ExperienceCreateRequest.HostId), refused.Errors.Keys);
    }

    [Fact]
    public async Task AHostMayNotPutAnExperienceOnSomebodyElse()
    {
        var mine = await fixture.AddUserAsync(Password, RoleNames.Host);
        var theirs = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        await Assert.ThrowsAsync<ForbiddenException>(() => AsAsync(
            Caller(mine, RoleNames.Host),
            experiences => experiences.CreateAsync(
                ExperienceRequests.New(references, "Not mine to give", hostId: theirs),
                CancellationToken.None)));
    }

    [Fact]
    public async Task AReferenceNothingHasIsRefusedUnderItsOwnField()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        await RefusedUnderAsync(
            host,
            references with { CityId = int.MaxValue },
            nameof(ExperienceCreateRequest.CityId));

        await RefusedUnderAsync(
            host,
            references with { CategoryId = int.MaxValue },
            nameof(ExperienceCreateRequest.ExperienceCategoryId));
    }

    [Fact]
    public async Task AHostEditsTheirOwnExperienceAndNobodyElses()
    {
        var mine = await fixture.AddUserAsync(Password, RoleNames.Host);
        var theirs = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var created = await CreateAsync(mine, references, "A cooking evening");

        var saved = await AsAsync(
            Caller(mine, RoleNames.Host),
            experiences => experiences.UpdateAsync(
                created,
                ExperienceRequests.Edit(references, "A longer cooking evening", price: 65m),
                CancellationToken.None));

        Assert.Equal("A longer cooking evening", saved.Title);
        Assert.Equal(65m, saved.PricePerPerson);

        await Assert.ThrowsAsync<ForbiddenException>(() => AsAsync(
            Caller(theirs, RoleNames.Host),
            experiences => experiences.UpdateAsync(
                created,
                ExperienceRequests.Edit(references, "Taken over"),
                CancellationToken.None)));

        await Assert.ThrowsAsync<ForbiddenException>(() => AsAsync(
            Caller(theirs, RoleNames.Host),
            experiences => experiences.DeleteAsync(created, CancellationToken.None)));
    }

    [Fact]
    public async Task AnAdministratorEditsAnybodysExperience()
    {
        var administrator = await fixture.AddUserAsync(Password, RoleNames.Administrator);
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var created = await CreateAsync(host, references, "A climb above the city");

        var saved = await AsAsync(
            Caller(administrator, RoleNames.Administrator),
            experiences => experiences.UpdateAsync(
                created,
                ExperienceRequests.Edit(references, "A climb above the city", isActive: false),
                CancellationToken.None));

        Assert.False(saved.IsActive);
        Assert.Equal(host, saved.HostId);
    }

    [Fact]
    public async Task AWithdrawnExperienceLeavesTheBrowseListButNotItsOwners()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var administrator = await fixture.AddUserAsync(Password, RoleNames.Administrator);
        var references = await ReferencesAsync();

        var open = await CreateAsync(host, references, "Still running");
        var withdrawn = await CreateAsync(host, references, "No longer running");

        await AsAsync(
            Caller(host, RoleNames.Host),
            experiences => experiences.UpdateAsync(
                withdrawn,
                ExperienceRequests.Edit(references, "No longer running", isActive: false),
                CancellationToken.None));

        Assert.Equal([open], await BrowsedByAsync(Caller(guest, RoleNames.Guest), host));

        await Assert.ThrowsAsync<NotFoundException>(() => AsAsync(
            Caller(guest, RoleNames.Guest),
            experiences => experiences.GetAsync(withdrawn, CancellationToken.None)));

        Assert.Equal(
            [open, withdrawn],
            (await BrowsedByAsync(Caller(host, RoleNames.Host), host)).Order());

        Assert.Equal(
            [open, withdrawn],
            (await BrowsedByAsync(Caller(administrator, RoleNames.Administrator), host)).Order());
    }

    [Fact]
    public async Task ASearchNarrowsByCityPriceAndDuration()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var here = await ReferencesAsync();
        var elsewhere = here with { CityId = await fixture.EnsureCityAsync("Mostar") };

        var wanted = await CreateAsync(
            host, here, "Two hours at forty", price: 40m, durationMinutes: 120);

        await CreateAsync(host, here, "Two hours at three hundred", price: 300m);
        await CreateAsync(host, here, "A whole day at forty", price: 40m, durationMinutes: 480);
        await CreateAsync(host, elsewhere, "Two hours at forty, elsewhere", price: 40m);

        var page = await AsAsync(
            Caller(host, RoleNames.Host),
            experiences => experiences.SearchAsync(
                new ExperienceSearchRequest
                {
                    HostId = host,
                    CityId = here.CityId,
                    MaxPrice = 100m,
                    MaxDurationMinutes = 180,
                },
                CancellationToken.None));

        Assert.Equal([wanted], page.Items.Select(item => item.Id));
        Assert.Equal(1, page.TotalCount);
    }

    [Fact]
    public async Task ASearchNarrowsByTitle()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var wanted = await CreateAsync(host, references, "An evening of ćevapi");

        await CreateAsync(host, references, "A morning of coffee");

        var page = await AsAsync(
            Caller(host, RoleNames.Host),
            experiences => experiences.SearchAsync(
                new ExperienceSearchRequest { HostId = host, Title = "evening" },
                CancellationToken.None));

        Assert.Equal([wanted], page.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task ADeletedExperienceTakesItsPhotosAndSlotsWithIt()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var references = await ReferencesAsync();

        var created = await CreateAsync(host, references, "A tour nobody booked");

        await using (var db = fixture.CreateContext())
        {
            db.ExperiencePhotos.Add(new ExperiencePhoto
            {
                ExperienceId = created,
                Image = [1, 2, 3],
                ContentType = "image/jpeg",
                IsCover = true,
                DisplayOrder = 0,
                UploadedAt = DateTime.UtcNow,
            });

            db.ExperienceSlots.Add(NewSlot(created));

            await db.SaveChangesAsync();
        }

        await AsAsync(
            Caller(host, RoleNames.Host),
            experiences => experiences.DeleteAsync(created, CancellationToken.None));

        await using var check = fixture.CreateContext();

        Assert.False(await check.Experiences.AnyAsync(row => row.Id == created));
        Assert.False(await check.ExperiencePhotos.AnyAsync(row => row.ExperienceId == created));
        Assert.False(await check.ExperienceSlots.AnyAsync(row => row.ExperienceId == created));
    }

    // The reservation holds the slot and the slot hangs off the experience, so
    // the cascade runs into the restrict one table further down than it does
    // for an accommodation.
    [Fact]
    public async Task AnExperienceWithAReservationIsRefusedRatherThanDeleted()
    {
        var host = await fixture.AddUserAsync(Password, RoleNames.Host);
        var guest = await fixture.AddUserAsync(Password, RoleNames.Guest);
        var references = await ReferencesAsync();

        var created = await CreateAsync(host, references, "A tour somebody booked");
        var now = DateTime.UtcNow;

        await using (var db = fixture.CreateContext())
        {
            var slot = NewSlot(created);

            db.ExperienceSlots.Add(slot);
            await db.SaveChangesAsync();

            db.Reservations.Add(new Reservation
            {
                UserId = guest,
                ExperienceSlotId = slot.Id,
                GuestCount = 2,
                ReservationStatusId = (int)ReservationStatusCode.Confirmed,
                ExpiresAt = now.AddDays(1),
                PricePerPerson = 40m,
                TotalPrice = 80m,
                CreatedAt = now,
            });

            await db.SaveChangesAsync();
        }

        var refused = await Assert.ThrowsAsync<BusinessException>(() => AsAsync(
            Caller(host, RoleNames.Host),
            experiences => experiences.DeleteAsync(created, CancellationToken.None)));

        Assert.Contains("Withdraw it", refused.Message);

        await using var check = fixture.CreateContext();

        Assert.True(await check.Experiences.AnyAsync(row => row.Id == created));
    }

    private static ExperienceSlot NewSlot(int experienceId) => new()
    {
        ExperienceId = experienceId,
        StartTime = DateTime.UtcNow.AddDays(7),
        DurationMinutes = 120,
        Capacity = 8,
        CreatedAt = DateTime.UtcNow,
    };

    private static ICurrentUser Caller(int userId, params string[] roles) =>
        new SignedInUser(userId, roles);

    private async Task<int> CreateAsync(
        int host,
        ExperienceReferences references,
        string title,
        decimal price = 40m,
        int durationMinutes = 120)
    {
        var created = await AsAsync(
            Caller(host, RoleNames.Host),
            experiences => experiences.CreateAsync(
                ExperienceRequests.New(
                    references, title, price: price, durationMinutes: durationMinutes),
                CancellationToken.None));

        return created.Id;
    }

    private async Task RefusedUnderAsync(int host, ExperienceReferences references, string field)
    {
        var refused = await Assert.ThrowsAsync<ValidationException>(() => AsAsync(
            Caller(host, RoleNames.Host),
            experiences => experiences.CreateAsync(
                ExperienceRequests.New(references, $"Refused under {field}"),
                CancellationToken.None)));

        Assert.Contains(field, refused.Errors.Keys);
    }

    private async Task<IReadOnlyList<int>> BrowsedByAsync(ICurrentUser caller, int host)
    {
        var page = await AsAsync(
            caller,
            experiences => experiences.SearchAsync(
                new ExperienceSearchRequest { HostId = host }, CancellationToken.None));

        return [.. page.Items.Select(item => item.Id)];
    }

    private async Task<ExperienceReferences> ReferencesAsync() =>
        new(
            await fixture.EnsureCityAsync("Sarajevo"),
            await fixture.EnsureExperienceCategoryAsync("Walking tour"));

    private async Task<T> AsAsync<T>(ICurrentUser caller, Func<IExperienceService, Task<T>> work)
    {
        await using var services = fixture.BuildServices(caller);

        return await work(services.GetRequiredService<IExperienceService>());
    }

    private async Task AsAsync(ICurrentUser caller, Func<IExperienceService, Task> work)
    {
        await using var services = fixture.BuildServices(caller);

        await work(services.GetRequiredService<IExperienceService>());
    }
}
