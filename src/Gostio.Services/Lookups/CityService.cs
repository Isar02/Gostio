using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Lookups;

internal sealed class CityService(GostioDbContext db, ILookupCache cache)
    : CachedLookupService<
        City,
        CityResponse,
        CitySearchRequest,
        CityUpsertRequest,
        CityUpsertRequest>(db, "city", cache),
      ICityService
{
    protected override Expression<Func<City, CityResponse>> Projection =>
        city => new CityResponse
        {
            Id = city.Id,
            Name = city.Name,
            CountryId = city.CountryId,
            CountryName = city.Country.Name,
        };

    protected override IOrderedQueryable<City> Order(IQueryable<City> query) =>
        query
            .OrderBy(city => city.Country.Name)
            .ThenBy(city => city.Name)
            .ThenBy(city => city.Id);

    protected override IQueryable<City> Filter(IQueryable<City> query, CitySearchRequest search)
    {
        if (Trimmed(search.Name) is string term)
        {
            query = query.Where(city => city.Name.Contains(term));
        }

        if (search.CountryId is int countryId)
        {
            query = query.Where(city => city.CountryId == countryId);
        }

        return query;
    }

    protected override async Task<City> NewAsync(
        CityUpsertRequest request,
        CancellationToken cancellationToken)
    {
        var city = new City();

        await ApplyAsync(request, city, cancellationToken);

        return city;
    }

    protected override async Task ApplyAsync(
        CityUpsertRequest request,
        City city,
        CancellationToken cancellationToken)
    {
        var name = request.Name.Trim();
        var countryId = request.CountryId;

        // Checked here rather than left to the foreign key, which cannot put a
        // message under the field that caused it.
        var isoCode = await Db.Countries
            .Where(country => country.Id == countryId)
            .Select(country => country.IsoCode)
            .FirstOrDefaultAsync(cancellationToken);

        if (isoCode is null)
        {
            throw new ValidationException(nameof(request.CountryId), "No country has this id.");
        }

        if (isoCode != HomeCountry.IsoCode)
        {
            throw new ValidationException(
                nameof(request.CountryId),
                $"This platform carries cities in {HomeCountry.Name} only.");
        }

        await RequireUniqueAsync(
            candidate => candidate.CountryId == countryId && candidate.Name == name,
            city.Id,
            nameof(request.Name),
            "This country already has a city by this name.",
            cancellationToken);

        city.Name = name;
        city.CountryId = countryId;
    }
}
