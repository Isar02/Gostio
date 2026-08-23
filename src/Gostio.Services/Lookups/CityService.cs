using System.Linq.Expressions;
using Gostio.Model.Exceptions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Lookups;

internal sealed class CityService(GostioDbContext db)
    : CrudService<City, CityResponse, CitySearchRequest, CityUpsertRequest, CityUpsertRequest>(
        db,
        "city"),
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

    // Grouped by country, because that is how the list reads: a city name is
    // only unique inside one.
    protected override IOrderedQueryable<City> Order(IQueryable<City> query) =>
        query
            .OrderBy(city => city.Country.Name)
            .ThenBy(city => city.Name)
            .ThenBy(city => city.Id);

    protected override IQueryable<City> Filter(IQueryable<City> query, CitySearchRequest search)
    {
        if (!string.IsNullOrWhiteSpace(search.Name))
        {
            string term = search.Name.Trim();

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

        // Checked here rather than left to the foreign key, which answers with
        // a provider error instead of a message under the field that caused it.
        if (!await Db.Countries.AnyAsync(country => country.Id == countryId, cancellationToken))
        {
            throw new ValidationException(nameof(request.CountryId), "No country has this id.");
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
