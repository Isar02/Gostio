namespace Gostio.Model.Responses;

// The single shape every failed request returns, so a client parses one thing.
public sealed class ErrorResponse
{
    public required int Status { get; init; }

    public required string Message { get; init; }

    public IReadOnlyDictionary<string, string[]>? Errors { get; init; }

    // Printed in the server log beside the exception, so a reported failure can
    // be found without asking the reporter to reproduce it.
    public required string TraceId { get; init; }
}
