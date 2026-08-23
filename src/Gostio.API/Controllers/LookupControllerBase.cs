using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Lookups;

namespace Gostio.API.Controllers;

public abstract class LookupControllerBase<TService>(TService service)
    : CrudControllerBase<
        TService,
        LookupResponse,
        LookupSearchRequest,
        LookupUpsertRequest,
        LookupUpsertRequest>(service)
    where TService : ILookupService;
