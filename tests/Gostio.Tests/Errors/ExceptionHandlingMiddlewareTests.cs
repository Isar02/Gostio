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

    [Fact]
    public async Task AnExpectedFailureKeepsItsStatusAndMessage()
    {
        var body = await RunAsync(new NotFoundException("No accommodation has that id."));

        Assert.Equal(StatusCodes.Status404NotFound, body.Status);
        Assert.Equal("No accommodation has that id.", body.Message);
        Assert.Null(body.Errors);
    }

    [Fact]
    public async Task AValidationFailureCarriesTheFieldThatCausedIt()
    {
        var body = await RunAsync(
            new ValidationException("Email", "Enter an address in the form name@example.com."));

        Assert.Equal(StatusCodes.Status400BadRequest, body.Status);
        Assert.NotNull(body.Errors);
        Assert.Equal(
            "Enter an address in the form name@example.com.",
            Assert.Single(body.Errors!["Email"]));
    }

    [Fact]
    public async Task AnUnexpectedFailureTellsTheClientNothingButTheTraceId()
    {
        var body = await RunAsync(new InvalidOperationException(Secret));

        Assert.Equal(StatusCodes.Status500InternalServerError, body.Status);
        Assert.DoesNotContain(Secret, body.Message);
        Assert.DoesNotContain("sa", body.Message);
        Assert.False(string.IsNullOrWhiteSpace(body.TraceId));
    }

    private static async Task<ErrorResponse> RunAsync(Exception thrown)
    {
        var context = new DefaultHttpContext();
        var written = new MemoryStream();

        context.Response.Body = written;

        var middleware = new ExceptionHandlingMiddleware(
            _ => throw thrown,
            NullLogger<ExceptionHandlingMiddleware>.Instance);

        await middleware.InvokeAsync(context);

        written.Position = 0;

        return (await JsonSerializer.DeserializeAsync<ErrorResponse>(
            written,
            new JsonSerializerOptions(JsonSerializerDefaults.Web)))!;
    }
}
