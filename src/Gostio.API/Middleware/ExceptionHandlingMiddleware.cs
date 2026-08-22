using Gostio.Model.Exceptions;
using Gostio.Model.Responses;

namespace Gostio.API.Middleware;

public sealed class ExceptionHandlingMiddleware(
    RequestDelegate next,
    ILogger<ExceptionHandlingMiddleware> logger)
{
    private const string UnexpectedMessage =
        "The request could not be completed. Quote the trace id when reporting this.";

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception exception)
        {
            var body = Describe(exception, context.TraceIdentifier);

            Log(exception, context, body.Status);

            // Nothing can be rewritten once the first byte is out, so the
            // exception goes on and aborts the connection instead.
            if (context.Response.HasStarted)
            {
                throw;
            }

            context.Response.Clear();
            context.Response.StatusCode = body.Status;

            await context.Response.WriteAsJsonAsync(body);
        }
    }

    // An expected failure states its own status and message. Everything else
    // gives up the trace id and nothing more, in every environment.
    private static ErrorResponse Describe(Exception exception, string traceId) =>
        exception is GostioException expected
            ? new ErrorResponse
            {
                Status = (int)expected.StatusCode,
                Message = expected.Message,
                Errors = (expected as ValidationException)?.Errors,
                TraceId = traceId,
            }
            : new ErrorResponse
            {
                Status = StatusCodes.Status500InternalServerError,
                Message = UnexpectedMessage,
                TraceId = traceId,
            };

    private void Log(Exception exception, HttpContext context, int status)
    {
        logger.Log(
            exception is GostioException ? LogLevel.Warning : LogLevel.Error,
            exception,
            "{Method} {Path} failed with {Status}. TraceId {TraceId}.",
            context.Request.Method,
            context.Request.Path,
            status,
            context.TraceIdentifier);
    }
}
