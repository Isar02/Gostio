using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Crud;

namespace Gostio.Services.Lookups;

public interface ICountryService : ICrudService<
    CountryResponse,
    CountrySearchRequest,
    CountryUpsertRequest,
    CountryUpsertRequest>;
