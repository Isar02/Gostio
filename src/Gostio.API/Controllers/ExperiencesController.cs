using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Listings;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/experiences")]
public sealed class ExperiencesController(IExperienceService experiences)
    : ListingsControllerBase<
        IExperienceService,
        ExperienceResponse,
        ExperienceSearchRequest,
        ExperienceCreateRequest,
        ExperienceUpdateRequest>(experiences);
