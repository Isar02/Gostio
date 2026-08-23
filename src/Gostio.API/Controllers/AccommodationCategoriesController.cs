using Gostio.Services.Lookups;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/accommodation-categories")]
public sealed class AccommodationCategoriesController(IAccommodationCategoryService service)
    : LookupControllerBase<IAccommodationCategoryService>(service);
