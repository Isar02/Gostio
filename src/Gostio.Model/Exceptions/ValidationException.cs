using System.Net;

namespace Gostio.Model.Exceptions;

public sealed class ValidationException : GostioException
{
    private const string DefaultMessage = "One or more values are not valid.";

    public ValidationException(string field, string message)
        : this(new Dictionary<string, string[]> { [field] = [message] })
    {
    }

    public ValidationException(IReadOnlyDictionary<string, string[]> errors)
        : base(DefaultMessage)
    {
        Errors = errors;
    }

    public override HttpStatusCode StatusCode => HttpStatusCode.BadRequest;

    // Keyed by the field the client sent, so a form can put each message under
    // the control that caused it rather than in one banner.
    public IReadOnlyDictionary<string, string[]> Errors { get; }
}
