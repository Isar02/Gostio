using Gostio.Model.Requests;
using Gostio.Model.Responses;

namespace Gostio.Services.Listings;

public interface IStayCalendarService
{
    Task<IReadOnlyList<StayCalendarDayResponse>> ReadAsync(
        int accommodationId,
        StayCalendarRequest request,
        CancellationToken cancellationToken);
}
