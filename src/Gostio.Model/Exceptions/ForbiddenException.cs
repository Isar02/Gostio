using System.Net;

namespace Gostio.Model.Exceptions;

public sealed class ForbiddenException(string message) : GostioException(message)
{
    public override HttpStatusCode StatusCode => HttpStatusCode.Forbidden;
}
