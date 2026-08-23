using Gostio.Services.Lookups;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/roles")]
public sealed class RolesController(IRoleService service)
    : LookupControllerBase<IRoleService>(service);
