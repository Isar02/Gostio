using System.Text;
using System.Text.Json;
using Gostio.API.Middleware;
using Gostio.Model.Exceptions;
using Gostio.Model.Responses;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;

namespace Gostio.Tests.Errors;

public class ExceptionHandlingMiddlewareTests
{
    private const string Secret = "Login failed for user 'sa'.";

    private static readonly JsonSerializerOptions Web = new(JsonSerializerDefaults.Web);

    [Fact]
    public async Task AnExpectedFailureKeepsItsStatusAndMessage()
    {
        var (_, body) = await RunAsync(new NotFoundException("No accommodation has that id."));

        Assert.Equal(StatusCodes.Status404NotFound, body.Status);
        Assert.Equal("No accommodation has that id.", body.Message);
        Assert.Null(body.Errors);
    }

    [Fact]
    public async Task AValidationFailureCarriesTheFieldThatCausedIt()
    {
        var (_, body) = await RunAsync(
            new ValidationException("Email", "Enter an address in the form name@example.com."));

        Assert.Equal(StatusCodes.Status400BadRequest, body.Status);
        Assert.NotNull(body.Errors);
        Assert.Equal(
            "Enter an address in the form name@example.com.",
            Assert.Single(body.Errors!["Email"]));
    }

    [Fact]
    public async Task AnUnexpectedFailureAnswersOneFixedSentenceAndNothingElse()
    {
        var (json, body) = await RunAsync(new InvalidOperationException(Secret));

        Assert.Equal(StatusCodes.Status500InternalServerError, body.Status);
        Assert.Equal(
            "The request could not be completed. Quote the trace id when reporting this.",
            body.Message);
        Assert.Null(body.Errors);
        Assert.False(string.IsNullOrWhiteSpace(body.TraceId));

        // The literal above and this list are the whole public contract of a
        // failed request: the reply may not grow a field that smuggles the
        // exception out with it.
        using var document = JsonDocument.Parse(json);

        string[] expected = ["status", "message", "errors", "traceId"];

        Assert.Equal(
            expected,
            document.RootElement.EnumerateObject().Select(property => property.Name));
    }

    private static async Task<(string Json, ErrorResponse Body)> RunAsync(Exception thrown)
    {
        var context = new DefaultHttpContext();
        var written = new MemoryStream();

        context.Response.Body = written;

        var middleware = new ExceptionHandlingMiddleware(
            _ => throw thrown,
            NullLogger<ExceptionHandlingMiddleware>.Instance);

        await middleware.InvokeAsync(context);

        var json = Encoding.UTF8.GetString(written.ToArray());

        return (json, JsonSerializer.Deserialize<ErrorResponse>(json, Web)!);
    }
}
