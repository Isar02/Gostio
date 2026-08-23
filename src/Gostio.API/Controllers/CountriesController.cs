using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Lookups;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/countries")]
public sealed class CountriesController(ICountryService service) : CrudControllerBase<
    ICountryService,
    CountryResponse,
    CountrySearchRequest,
    CountryUpsertRequest,
    CountryUpsertRequest>(service);
