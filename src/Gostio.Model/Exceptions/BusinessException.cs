using System.Net;

namespace Gostio.Model.Exceptions;

// A request that is well formed but asks for something the current state does
// not allow, such as paying a reservation that is already paid.
public sealed class BusinessException(string message) : GostioException(message)
{
    public override HttpStatusCode StatusCode => HttpStatusCode.Conflict;
}
