using Gostio.Model.Authorization;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Database.Seeding;

internal sealed record LookupSeedResult(
    IReadOnlyDictionary<string, Role> Roles,
    IReadOnlyDictionary<string, City> Cities,
    IReadOnlyDictionary<string, AccommodationType> AccommodationTypes,
    IReadOnlyDictionary<string, AccommodationCategory> AccommodationCategories,
    IReadOnlyDictionary<string, ExperienceCategory> ExperienceCategories,
    IReadOnlyDictionary<string, Amenity> Amenities);

// ReservationStatuses are absent here: HasData owns them, so their ids stay fixed.
internal static class LookupSeed
{
    public static async Task<LookupSeedResult> SeedAsync(
        GostioDbContext db,
        CancellationToken cancellationToken)
    {
        var roles = ByName<Role>(RoleNames.All);

        var countries = ByName(
            new[]
            {
                new Country { Name = "Bosnia and Herzegovina", IsoCode = "BA" },
                new Country { Name = "Croatia", IsoCode = "HR" },
                new Country { Name = "Montenegro", IsoCode = "ME" },
                new Country { Name = "Serbia", IsoCode = "RS" },
                new Country { Name = "Slovenia", IsoCode = "SI" }
            },
            country => country.Name);

        City InCountry(string name, string country) =>
            new() { Name = name, Country = countries[country] };

        const string Bosnia = "Bosnia and Herzegovina";

        var cities = ByName(
            new[]
            {
                InCountry("Sarajevo", Bosnia),
                InCountry("Mostar", Bosnia),
                InCountry("Banja Luka", Bosnia),
                InCountry("Tuzla", Bosnia),
                InCountry("Trebinje", Bosnia),
                InCountry("Jajce", Bosnia),
                InCountry("Bihać", Bosnia),
                InCountry("Neum", Bosnia),
                InCountry("Dubrovnik", "Croatia"),
                InCountry("Split", "Croatia"),
                InCountry("Zagreb", "Croatia"),
                InCountry("Kotor", "Montenegro"),
                InCountry("Budva", "Montenegro"),
                InCountry("Belgrade", "Serbia"),
                InCountry("Novi Sad", "Serbia"),
                InCountry("Ljubljana", "Slovenia")
            },
            city => city.Name);

        var accommodationTypes = ByName<AccommodationType>(
            ["Apartment", "House", "Private room", "Villa", "Studio", "Cottage"]);

        var accommodationCategories = ByName<AccommodationCategory>(
            ["City break", "Seaside", "Mountain", "Countryside", "Historic", "Luxury"]);

        var experienceCategories = ByName<ExperienceCategory>(
        [
            "Food and drink",
            "Nature and outdoors",
            "History and culture",
            "Adventure",
            "Wellness",
            "Nightlife"
        ]);

        var amenities = ByName<Amenity>(
        [
            "Wi-Fi",
            "Air conditioning",
            "Kitchen",
            "Free parking",
            "Washing machine",
            "TV",
            "Heating",
            "Balcony",
            "Swimming pool",
            "Pet friendly",
            "Workspace",
            "Breakfast"
        ]);

        db.AddRange(roles.Values);
        db.AddRange(countries.Values);
        db.AddRange(cities.Values);
        db.AddRange(accommodationTypes.Values);
        db.AddRange(accommodationCategories.Values);
        db.AddRange(experienceCategories.Values);
        db.AddRange(amenities.Values);

        await db.SaveChangesAsync(cancellationToken);

        return new LookupSeedResult(
            roles,
            cities,
            accommodationTypes,
            accommodationCategories,
            experienceCategories,
            amenities);
    }

    private static Dictionary<string, TEntity> ByName<TEntity>(IEnumerable<string> names)
        where TEntity : ILookupEntity, new()
        => names.Select(name => new TEntity { Name = name }).ToDictionary(entity => entity.Name);

    private static Dictionary<string, TEntity> ByName<TEntity>(
        IEnumerable<TEntity> entities,
        Func<TEntity, string> name)
        => entities.ToDictionary(name);
}
