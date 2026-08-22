using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Net.Http.Json;
using Gostio.API.Middleware;
using Gostio.Model.Responses;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using GostioValidationException = Gostio.Model.Exceptions.ValidationException;

namespace Gostio.Tests.Errors;

// A host carrying nothing but the two registrations under test, so a failure
// here is theirs and not the API's configuration or database.
public sealed class ErrorResponsesTests : IAsyncLifetime
{
    private WebApplication app = null!;

    private HttpClient client = null!;

    public async Task InitializeAsync()
    {
        var builder = WebApplication.CreateBuilder();

        builder.Logging.ClearProviders();
        builder.WebHost.UseTestServer();

        builder.Services
            .AddControllers()
            .AddApplicationPart(typeof(ProbeController).Assembly);

        builder.Services.AddGostioValidationErrors();

        app = builder.Build();

        app.UseGostioStatusCodeErrors();
        app.MapControllers();

        await app.StartAsync();

        client = app.GetTestClient();
    }

    public async Task DisposeAsync()
    {
        client.Dispose();

        await app.DisposeAsync();
    }

    [Fact]
    public async Task ABodyThatFailsValidationComesBackInTheSharedShape()
    {
        var response = await client.PostAsJsonAsync("/probe", new { });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        Assert.NotNull(body);
        Assert.Equal(GostioValidationException.DefaultMessage, body!.Message);
        Assert.Equal(
            "Enter an address in the form name@example.com.",
            Assert.Single(body.Errors!["Email"]));
    }

    [Fact]
    public async Task AnAddressNothingAnswersComesBackInTheSharedShape()
    {
        var response = await client.GetAsync("/nothing-answers-this");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<ErrorResponse>();

        Assert.NotNull(body);
        Assert.Equal(StatusCodes.Status404NotFound, body!.Status);
        Assert.Equal("No resource matches this address.", body.Message);
        Assert.False(string.IsNullOrWhiteSpace(body.TraceId));
    }

    // Reachable over HTTP only through a binder that fails with an exception
    // rather than a message, which is why it is driven straight at the factory.
    [Fact]
    public void AModelErrorWithoutAMessageNeverAnswersWithAnEmptyOne()
    {
        var options = new ServiceCollection()
            .AddGostioValidationErrors()
            .BuildServiceProvider()
            .GetRequiredService<IOptions<ApiBehaviorOptions>>()
            .Value;

        var modelState = new ModelStateDictionary();

        modelState.AddModelError("Email", string.Empty);

        var result = Assert.IsType<BadRequestObjectResult>(
            options.InvalidModelStateResponseFactory(
                new ActionContext(
                    new DefaultHttpContext(),
                    new RouteData(),
                    new ActionDescriptor(),
                    modelState)));

        var body = Assert.IsType<ErrorResponse>(result.Value);

        Assert.Equal("This value could not be read.", Assert.Single(body.Errors!["Email"]));
    }
}

public sealed class ProbeRequest
{
    [Required(ErrorMessage = "Enter an address in the form name@example.com.")]
    public string? Email { get; set; }
}

[ApiController]
[Route("probe")]
public sealed class ProbeController : ControllerBase
{
    [HttpPost]
    public IActionResult Post(ProbeRequest request) => Ok(request.Email);
}
