using Gostio.Services.Lookups;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/amenities")]
public sealed class AmenitiesController(IAmenityService service)
    : LookupControllerBase<IAmenityService>(service);
