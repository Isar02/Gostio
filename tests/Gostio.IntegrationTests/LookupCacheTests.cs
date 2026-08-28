using Gostio.Model.Requests;
using Gostio.Services.Database.Entities;
using Gostio.Services.Lookups;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class LookupCacheTests(DatabaseFixture fixture)
{
    [Fact]
    public async Task TheWholeTableIsReadOnceAndEveryPageAfterThatIsCutOutOfMemory()
    {
        var counter = new CommandCounter("Amenities");

        await using var services = fixture.BuildServices(null, counter);

        var amenities = services.GetRequiredService<IAmenityService>();

        foreach (var name in new[] { "Wine cellar", "Roof terrace", "Log burner", "Wet room" })
        {
            await amenities.CreateAsync(Named(name), CancellationToken.None);
        }

        var beforeTheFirstRead = counter.Reads;

        var whole = await amenities.SearchAsync(
            new LookupSearchRequest { PageSize = 100 }, CancellationToken.None);

        // One query and not the two a paged query issues: what is held is the
        // table rather than the page cut out of it.
        Assert.Equal(beforeTheFirstRead + 1, counter.Reads);

        var warm = counter.Reads;

        var second = await amenities.SearchAsync(
            new LookupSearchRequest { Page = 2, PageSize = 2 }, CancellationToken.None);

        Assert.Equal(warm, counter.Reads);
        Assert.Equal(whole.TotalCount, second.TotalCount);
        Assert.Equal(
            whole.Items.Skip(2).Take(2).Select(item => item.Name),
            second.Items.Select(item => item.Name));
    }

    [Fact]
    public async Task APageBeginningPastTheLastRowIsEmptyWithoutReachingTheDatabaseAgain()
    {
        var counter = new CommandCounter("Amenities");

        await using var services = fixture.BuildServices(null, counter);

        var amenities = services.GetRequiredService<IAmenityService>();

        var whole = await amenities.SearchAsync(
            new LookupSearchRequest { PageSize = 100 }, CancellationToken.None);

        var warm = counter.Reads;

        var beyond = await amenities.SearchAsync(
            new LookupSearchRequest { Page = 500, PageSize = 100 }, CancellationToken.None);

        Assert.Equal(warm, counter.Reads);
        Assert.Empty(beyond.Items);
        Assert.Equal(whole.TotalCount, beyond.TotalCount);
    }

    [Fact]
    public async Task ASearchNamingANameIsAnsweredByTheDatabase()
    {
        var counter = new CommandCounter("Amenities");

        await using var services = fixture.BuildServices(null, counter);

        var amenities = services.GetRequiredService<IAmenityService>();

        await amenities.CreateAsync(Named("Steam room"), CancellationToken.None);
        await amenities.SearchAsync(new LookupSearchRequest(), CancellationToken.None);

        var warm = counter.Reads;

        var page = await amenities.SearchAsync(
            new LookupSearchRequest { Name = "Steam room" }, CancellationToken.None);

        Assert.True(counter.Reads > warm);
        Assert.Equal(["Steam room"], page.Items.Select(item => item.Name));
    }

    [Fact]
    public async Task ACitySearchNamingANameIsAnsweredByTheDatabase()
    {
        var counter = new CommandCounter("Cities");

        await using var services = fixture.BuildServices(null, counter);

        var cities = services.GetRequiredService<ICityService>();
        var country = await NewCountryAsync(services, "Slovakia", "SK");

        await cities.CreateAsync(City("Kosice", country), CancellationToken.None);
        await cities.SearchAsync(new CitySearchRequest(), CancellationToken.None);

        var warm = counter.Reads;

        var page = await cities.SearchAsync(
            new CitySearchRequest { Name = "Kosice" }, CancellationToken.None);

        Assert.True(counter.Reads > warm);
        Assert.Equal(["Kosice"], page.Items.Select(item => item.Name));
    }

    [Fact]
    public async Task ACitySearchNamingACountryIsAnsweredByTheDatabase()
    {
        var counter = new CommandCounter("Cities");

        await using var services = fixture.BuildServices(null, counter);

        var cities = services.GetRequiredService<ICityService>();
        var country = await NewCountryAsync(services, "Hungary", "HU");

        await cities.CreateAsync(City("Pecs", country), CancellationToken.None);
        await cities.SearchAsync(new CitySearchRequest(), CancellationToken.None);

        var warm = counter.Reads;

        var page = await cities.SearchAsync(
            new CitySearchRequest { CountryId = country }, CancellationToken.None);

        Assert.True(counter.Reads > warm);
        Assert.Equal(["Pecs"], page.Items.Select(item => item.Name));
    }

    [Fact]
    public async Task ACountrySearchNamingACodeIsAnsweredByTheDatabase()
    {
        var counter = new CommandCounter("Countries");

        await using var services = fixture.BuildServices(null, counter);

        var countries = services.GetRequiredService<ICountryService>();

        await countries.CreateAsync(Country("Sweden", "SE"), CancellationToken.None);
        await countries.SearchAsync(new CountrySearchRequest(), CancellationToken.None);

        var warm = counter.Reads;

        var page = await countries.SearchAsync(
            new CountrySearchRequest { IsoCode = "SE" }, CancellationToken.None);

        Assert.True(counter.Reads > warm);
        Assert.Equal(["Sweden"], page.Items.Select(item => item.Name));
    }

    [Fact]
    public async Task ACountrySearchNamingANameIsAnsweredByTheDatabase()
    {
        var counter = new CommandCounter("Countries");

        await using var services = fixture.BuildServices(null, counter);

        var countries = services.GetRequiredService<ICountryService>();

        await countries.CreateAsync(Country("Romania", "RO"), CancellationToken.None);
        await countries.SearchAsync(new CountrySearchRequest(), CancellationToken.None);

        var warm = counter.Reads;

        var page = await countries.SearchAsync(
            new CountrySearchRequest { Name = "Romania" }, CancellationToken.None);

        Assert.True(counter.Reads > warm);
        Assert.Equal(["Romania"], page.Items.Select(item => item.Name));
    }

    [Fact]
    public async Task ACreatedRowIsInTheNextRead()
    {
        await using var services = fixture.BuildServices();

        var amenities = services.GetRequiredService<IAmenityService>();

        await WholeAsync(amenities);

        await amenities.CreateAsync(Named("Boot room"), CancellationToken.None);

        Assert.Contains("Boot room", await WholeAsync(amenities));
    }

    [Fact]
    public async Task AnEditIsVisibleOnTheNextRead()
    {
        await using var services = fixture.BuildServices();

        var amenities = services.GetRequiredService<IAmenityService>();

        var created = await amenities.CreateAsync(Named("Games room"), CancellationToken.None);

        await WholeAsync(amenities);

        await amenities.UpdateAsync(created.Id, Named("Games barn"), CancellationToken.None);

        var names = await WholeAsync(amenities);

        Assert.Contains("Games barn", names);
        Assert.DoesNotContain("Games room", names);
    }

    [Fact]
    public async Task ADeletedRowIsGoneFromTheNextRead()
    {
        await using var services = fixture.BuildServices();

        var amenities = services.GetRequiredService<IAmenityService>();

        var created = await amenities.CreateAsync(Named("Bike shed"), CancellationToken.None);

        await WholeAsync(amenities);

        await amenities.DeleteAsync(created.Id, CancellationToken.None);

        Assert.DoesNotContain("Bike shed", await WholeAsync(amenities));
    }

    // A city answers with a column of its country, so the write that corrects
    // the stale rows is not a write to the table they are in.
    [Fact]
    public async Task ARenamedCountryChangesTheNameEveryCityReports()
    {
        await using var services = fixture.BuildServices();

        var countries = services.GetRequiredService<ICountryService>();
        var cities = services.GetRequiredService<ICityService>();

        var country = await countries.CreateAsync(Country("Latvia", "LV"), CancellationToken.None);

        await cities.CreateAsync(City("Liepaja", country.Id), CancellationToken.None);

        var before = await cities.SearchAsync(
            new CitySearchRequest { PageSize = 100 }, CancellationToken.None);

        Assert.Contains(
            before.Items,
            city => city.Name == "Liepaja" && city.CountryName == "Latvia");

        await countries.UpdateAsync(
            country.Id, Country("Republic of Latvia", "LV"), CancellationToken.None);

        var after = await cities.SearchAsync(
            new CitySearchRequest { PageSize = 100 }, CancellationToken.None);

        Assert.Contains(
            after.Items,
            city => city.Name == "Liepaja" && city.CountryName == "Republic of Latvia");
    }

    // The load is held open while a write lands, which is the one ordering the
    // eviction on its own cannot answer: the rows were read before the write
    // and are stored after it.
    [Fact]
    public async Task RowsReadBeforeAWriteAreAnsweredWithAndNotKept()
    {
        await using var services = fixture.BuildServices();

        var cache = services.GetRequiredService<ILookupCache>();

        var loading = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var written = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        var read = cache.ReadAsync(
            typeof(Amenity),
            async _ =>
            {
                loading.SetResult();

                await written.Task;

                return new List<string> { "what the table held" };
            },
            CancellationToken.None);

        await loading.Task;

        cache.Evict(typeof(Amenity));

        written.SetResult();

        Assert.Equal(["what the table held"], await read);

        var next = await cache.ReadAsync(
            typeof(Amenity),
            _ => Task.FromResult(new List<string> { "what it holds now" }),
            CancellationToken.None);

        Assert.Equal(["what it holds now"], next);
    }

    [Fact]
    public async Task OneLoaderFillsAColdTableAndTheRestWaitForIt()
    {
        await using var services = fixture.BuildServices();

        var cache = services.GetRequiredService<ILookupCache>();

        var loads = 0;
        var loading = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        async Task<List<string>> LoadAsync(CancellationToken cancellationToken)
        {
            if (Interlocked.Increment(ref loads) == 1)
            {
                loading.SetResult();

                await release.Task;
            }

            return ["the only list"];
        }

        var first = cache.ReadAsync(typeof(Role), LoadAsync, CancellationToken.None);

        await loading.Task;

        var second = cache.ReadAsync(typeof(Role), LoadAsync, CancellationToken.None);

        Assert.False(second.IsCompleted);

        release.SetResult();

        Assert.Equal(["the only list"], await first);
        Assert.Equal(["the only list"], await second);
        Assert.Equal(1, Volatile.Read(ref loads));
    }

    // The row is committed before the call reads it back, so a failure after
    // that point leaves a written table and a list that predates it.
    [Fact]
    public async Task AWriteWhoseReadbackFailsStillDropsWhatIsHeld()
    {
        var failure = new CommandFailure("SELECT TOP(1)", "[Amenities]");

        await using var services = fixture.BuildServices(null, failure);

        var amenities = services.GetRequiredService<IAmenityService>();

        await WholeAsync(amenities);

        Assert.NotNull(
            await Record.ExceptionAsync(
                () => amenities.CreateAsync(Named("Drying room"), CancellationToken.None)));

        Assert.True(failure.Thrown);

        await using (var db = fixture.CreateContext())
        {
            Assert.True(
                await db.Amenities.AnyAsync(amenity => amenity.Name == "Drying room"));
        }

        Assert.Contains("Drying room", await WholeAsync(amenities));
    }

    // The rows are stored whatever landed while they were in flight, so the
    // entry here is written after the write that superseded it. What must hold
    // is that no reader is served it and that the key still caches afterwards.
    [Fact]
    public async Task AListSupersededWhileItWasReadIsNeverServedAndLeavesTheKeyUsable()
    {
        await using var services = fixture.BuildServices();

        var cache = services.GetRequiredService<ILookupCache>();

        var loading = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var written = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        var superseded = cache.ReadAsync(
            typeof(City),
            async _ =>
            {
                loading.SetResult();

                await written.Task;

                return new List<string> { "before the write" };
            },
            CancellationToken.None);

        await loading.Task;

        cache.Evict(typeof(City));

        written.SetResult();

        await superseded;

        var loads = 0;

        Task<List<string>> LoadAsync(CancellationToken cancellationToken)
        {
            Interlocked.Increment(ref loads);

            return Task.FromResult(new List<string> { "after the write" });
        }

        var next = await cache.ReadAsync(typeof(City), LoadAsync, CancellationToken.None);
        var again = await cache.ReadAsync(typeof(City), LoadAsync, CancellationToken.None);

        Assert.Equal(["after the write"], next);
        Assert.Equal(["after the write"], again);
        Assert.Equal(1, Volatile.Read(ref loads));
    }

    private static async Task<int> NewCountryAsync(
        IServiceProvider services,
        string name,
        string isoCode)
    {
        var created = await services
            .GetRequiredService<ICountryService>()
            .CreateAsync(Country(name, isoCode), CancellationToken.None);

        return created.Id;
    }

    private static async Task<IReadOnlyList<string>> WholeAsync(IAmenityService amenities)
    {
        var page = await amenities.SearchAsync(
            new LookupSearchRequest { PageSize = 100 }, CancellationToken.None);

        return [.. page.Items.Select(item => item.Name)];
    }

    private static LookupUpsertRequest Named(string name) => new() { Name = name };

    private static CountryUpsertRequest Country(string name, string isoCode) =>
        new() { Name = name, IsoCode = isoCode };

    private static CityUpsertRequest City(string name, int countryId) =>
        new() { Name = name, CountryId = countryId };
}
