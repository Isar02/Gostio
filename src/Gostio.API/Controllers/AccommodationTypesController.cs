using Gostio.Services.Lookups;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/accommodation-types")]
public sealed class AccommodationTypesController(IAccommodationTypeService service)
    : LookupControllerBase<IAccommodationTypeService>(service);
