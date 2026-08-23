using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Lookups;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/reservation-statuses")]
public sealed class ReservationStatusesController(IReservationStatusService service)
    : CrudControllerBase<
        IReservationStatusService,
        ReservationStatusResponse,
        LookupSearchRequest,
        ReservationStatusUpsertRequest,
        ReservationStatusUpsertRequest>(service);
