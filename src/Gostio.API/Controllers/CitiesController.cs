using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Lookups;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/cities")]
public sealed class CitiesController(ICityService service) : CrudControllerBase<
    ICityService,
    CityResponse,
    CitySearchRequest,
    CityUpsertRequest,
    CityUpsertRequest>(service);
