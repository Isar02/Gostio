using Gostio.Services.Lookups;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/experience-categories")]
public sealed class ExperienceCategoriesController(IExperienceCategoryService service)
    : LookupControllerBase<IExperienceCategoryService>(service);
