using System.Net;

namespace Gostio.Model.Exceptions;

public sealed class NotFoundException(string message) : GostioException(message)
{
    public override HttpStatusCode StatusCode => HttpStatusCode.NotFound;
}
