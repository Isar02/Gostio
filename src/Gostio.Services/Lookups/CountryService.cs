using System.Linq.Expressions;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;
using Gostio.Services.Database;
using Gostio.Services.Database.Entities;

namespace Gostio.Services.Lookups;

internal sealed class CountryService(GostioDbContext db)
    : CrudService<
        Country,
        CountryResponse,
        CountrySearchRequest,
        CountryUpsertRequest,
        CountryUpsertRequest>(db, "country"),
      ICountryService
{
    protected override Expression<Func<Country, CountryResponse>> Projection =>
        country => new CountryResponse
        {
            Id = country.Id,
            Name = country.Name,
            IsoCode = country.IsoCode,
        };

    protected override IOrderedQueryable<Country> Order(IQueryable<Country> query) =>
        query.OrderBy(country => country.Name).ThenBy(country => country.Id);

    protected override IQueryable<Country> Filter(
        IQueryable<Country> query,
        CountrySearchRequest search)
    {
        if (!string.IsNullOrWhiteSpace(search.Name))
        {
            string term = search.Name.Trim();

            query = query.Where(country => country.Name.Contains(term));
        }

        if (!string.IsNullOrWhiteSpace(search.IsoCode))
        {
            string code = search.IsoCode.Trim();

            query = query.Where(country => country.IsoCode == code);
        }

        return query;
    }

    protected override async Task<Country> NewAsync(
        CountryUpsertRequest request,
        CancellationToken cancellationToken)
    {
        var country = new Country();

        await ApplyAsync(request, country, cancellationToken);

        return country;
    }

    protected override async Task ApplyAsync(
        CountryUpsertRequest request,
        Country country,
        CancellationToken cancellationToken)
    {
        var name = request.Name.Trim();
        var isoCode = request.IsoCode.Trim().ToUpperInvariant();

        await RequireUniqueAsync(
            candidate => candidate.Name == name,
            country.Id,
            nameof(request.Name),
            "Another country already goes by this name.",
            cancellationToken);

        await RequireUniqueAsync(
            candidate => candidate.IsoCode == isoCode,
            country.Id,
            nameof(request.IsoCode),
            "Another country already has this code.",
            cancellationToken);

        country.Name = name;
        country.IsoCode = isoCode;
    }
}
