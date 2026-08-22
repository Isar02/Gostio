using System.Net;

namespace Gostio.Model.Exceptions;

public sealed class UnauthorizedException(string message) : GostioException(message)
{
    public override HttpStatusCode StatusCode => HttpStatusCode.Unauthorized;
}
