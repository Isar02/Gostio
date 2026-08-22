using System.Net;

namespace Gostio.Model.Exceptions;

// Everything thrown on purpose derives from this: the middleware shows these
// messages to the client and replaces every other one. StatusCode is abstract
// so a new type cannot compile without saying what the client should see.
public abstract class GostioException(string message) : Exception(message)
{
    public abstract HttpStatusCode StatusCode { get; }
}
