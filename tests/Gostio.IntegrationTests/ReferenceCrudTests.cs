using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Validation;
using Gostio.Services.Lookups;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

// The three reference tables that carry a column of their own, so the shared
// base is not the whole story: an iso code, a country a city has to be in, and
// four rows the reservation state machine names by id.
[Collection(DatabaseCollection.Name)]
public class ReferenceCrudTests(DatabaseFixture fixture)
{
    [Fact]
    public async Task ACountryCodeIsStoredInCapitals()
    {
        await using var services = fixture.BuildServices();

        var created = await services
            .GetRequiredService<ICountryService>()
            .CreateAsync(Country("Iceland", "is"), CancellationToken.None);

        Assert.Equal("IS", created.IsoCode);
    }

    [Fact]
    public async Task ASecondCountryCannotTakeACodeThatIsAlreadyUsed()
    {
        await using var services = fixture.BuildServices();

        var countries = services.GetRequiredService<ICountryService>();

        await countries.CreateAsync(Country("Norway", "NO"), CancellationToken.None);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => countries.CreateAsync(Country("Nordland", "no"), CancellationToken.None));

        Assert.Contains(nameof(CountryUpsertRequest.IsoCode), refused.Errors.Keys);
    }

    [Fact]
    public async Task ACountrySearchNarrowsByCode()
    {
        await using var services = fixture.BuildServices();

        var countries = services.GetRequiredService<ICountryService>();

        await countries.CreateAsync(Country("Portugal", "PT"), CancellationToken.None);
        await countries.CreateAsync(Country("Poland", "PL"), CancellationToken.None);

        var page = await countries.SearchAsync(
            new CountrySearchRequest { IsoCode = "PL" }, CancellationToken.None);

        Assert.Equal(["Poland"], page.Items.Select(item => item.Name));
    }

    [Fact]
    public async Task TheCountryTheCitiesAreInDoesNotChangeItsCode()
    {
        await using var services = fixture.BuildServices();

        var countries = services.GetRequiredService<ICountryService>();
        var country = await fixture.EnsureHomeCountryAsync();

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => countries.UpdateAsync(
                country, Country(HomeCountry.Name, "ZZ"), CancellationToken.None));

        Assert.Contains(nameof(CountryUpsertRequest.IsoCode), refused.Errors.Keys);
    }

    [Fact]
    public async Task ACityAnswersWithTheCountryItIsIn()
    {
        await using var services = fixture.BuildServices();

        var country = await fixture.EnsureHomeCountryAsync();

        var city = await services
            .GetRequiredService<ICityService>()
            .CreateAsync(City("Odžak", country), CancellationToken.None);

        Assert.Equal(country, city.CountryId);
        Assert.Equal(HomeCountry.Name, city.CountryName);
    }

    [Fact]
    public async Task ACityInACountryThatDoesNotExistIsRefusedUnderItsOwnField()
    {
        await using var services = fixture.BuildServices();

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => services
                .GetRequiredService<ICityService>()
                .CreateAsync(City("Nowhere", int.MaxValue), CancellationToken.None));

        Assert.Contains(nameof(CityUpsertRequest.CountryId), refused.Errors.Keys);
    }

    // The unique index is on the pair, and so is the check in front of it.
    [Fact]
    public async Task ACityNameIsTakenOnlyOnceInTheCountry()
    {
        await using var services = fixture.BuildServices();

        var cities = services.GetRequiredService<ICityService>();
        var country = await fixture.EnsureHomeCountryAsync();

        await cities.CreateAsync(City("Maglaj", country), CancellationToken.None);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => cities.CreateAsync(City("Maglaj", country), CancellationToken.None));

        Assert.Contains(nameof(CityUpsertRequest.Name), refused.Errors.Keys);
    }

    [Fact]
    public async Task ACityOutsideTheOneCountryIsRefusedUnderItsOwnField()
    {
        await using var services = fixture.BuildServices();

        var abroad = await services
            .GetRequiredService<ICountryService>()
            .CreateAsync(Country("Austria", "AT"), CancellationToken.None);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => services
                .GetRequiredService<ICityService>()
                .CreateAsync(City("Salzburg", abroad.Id), CancellationToken.None));

        Assert.Contains(nameof(CityUpsertRequest.CountryId), refused.Errors.Keys);
    }

    [Fact]
    public async Task ACityIsNotMovedOutOfTheCountryByAnUpdate()
    {
        await using var services = fixture.BuildServices();

        var cities = services.GetRequiredService<ICityService>();

        var abroad = await services
            .GetRequiredService<ICountryService>()
            .CreateAsync(Country("Slovakia", "SK"), CancellationToken.None);

        var city = await cities.CreateAsync(
            City("Tešanj", await fixture.EnsureHomeCountryAsync()), CancellationToken.None);

        var refused = await Assert.ThrowsAsync<ValidationException>(
            () => cities.UpdateAsync(city.Id, City(city.Name, abroad.Id), CancellationToken.None));

        Assert.Contains(nameof(CityUpsertRequest.CountryId), refused.Errors.Keys);
    }

    [Fact]
    public async Task ACountryACityPointsAtIsNotDeleted()
    {
        await using var services = fixture.BuildServices();

        var countries = services.GetRequiredService<ICountryService>();
        var country = await fixture.EnsureHomeCountryAsync();

        await services
            .GetRequiredService<ICityService>()
            .CreateAsync(City("Srebrenik", country), CancellationToken.None);

        await Assert.ThrowsAsync<BusinessException>(
            () => countries.DeleteAsync(country, CancellationToken.None));
    }

    [Fact]
    public async Task TheMigrationLeavesEveryStatusTheStateMachineNames()
    {
        await using var services = fixture.BuildServices();

        var page = await services
            .GetRequiredService<IReservationStatusService>()
            .SearchAsync(new LookupSearchRequest(), CancellationToken.None);

        Assert.Equal(
            Enum.GetValues<ReservationStatusCode>().Select(code => code.ToString()),
            page.Items.Select(item => item.Code));
    }

    [Fact]
    public async Task ASeededStatusIsRenamedButKeepsItsCode()
    {
        await using var services = fixture.BuildServices();

        var statuses = services.GetRequiredService<IReservationStatusService>();
        var id = (int)ReservationStatusCode.Pending;

        var renamed = await statuses.UpdateAsync(
            id,
            Status("Awaiting payment", nameof(ReservationStatusCode.Pending), "Held for now."),
            CancellationToken.None);

        Assert.Equal("Awaiting payment", renamed.Name);
        Assert.Equal(nameof(ReservationStatusCode.Pending), renamed.Code);
        Assert.Equal("Held for now.", renamed.Description);

        await Assert.ThrowsAsync<BusinessException>(
            () => statuses.UpdateAsync(
                id, Status("Awaiting payment", "Held", null), CancellationToken.None));
    }

    [Fact]
    public async Task ASeededStatusIsNotDeleted()
    {
        await using var services = fixture.BuildServices();

        var statuses = services.GetRequiredService<IReservationStatusService>();

        await Assert.ThrowsAsync<BusinessException>(
            () => statuses.DeleteAsync(
                (int)ReservationStatusCode.Completed, CancellationToken.None));

        await using var db = fixture.CreateContext();

        Assert.True(await db.ReservationStatuses.AnyAsync(
            status => status.Id == (int)ReservationStatusCode.Completed));
    }

    // Nothing in the code names it, so nothing has to protect it either.
    [Fact]
    public async Task AStatusAnAdministratorAddsIsEditableAndDeletableInFull()
    {
        await using var services = fixture.BuildServices();

        var statuses = services.GetRequiredService<IReservationStatusService>();

        var created = await statuses.CreateAsync(
            Status("Disputed", "Disputed", "Raised with the payment provider."),
            CancellationToken.None);

        Assert.True(created.Id > Enum.GetValues<ReservationStatusCode>().Length);

        var changed = await statuses.UpdateAsync(
            created.Id, Status("In dispute", "InDispute", null), CancellationToken.None);

        Assert.Equal("InDispute", changed.Code);
        Assert.Null(changed.Description);

        await statuses.DeleteAsync(created.Id, CancellationToken.None);

        await Assert.ThrowsAsync<NotFoundException>(
            () => statuses.GetAsync(created.Id, CancellationToken.None));
    }

    private static CountryUpsertRequest Country(string name, string isoCode) =>
        new() { Name = name, IsoCode = isoCode };

    private static CityUpsertRequest City(string name, int countryId) =>
        new() { Name = name, CountryId = countryId };

    private static ReservationStatusUpsertRequest Status(
        string name,
        string code,
        string? description) =>
        new() { Name = name, Code = code, Description = description };
}
