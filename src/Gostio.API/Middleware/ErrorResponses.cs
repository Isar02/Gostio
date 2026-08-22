using Gostio.Model.Exceptions;
using Gostio.Model.Responses;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Middleware;

// Only a failure that surfaces as an exception reaches the middleware. Model
// binding answers 400 on its own, and routing, authentication and authorization
// answer 404, 401 and 403 with no body at all, so without these two a client
// would have to read three shapes for one class of problem.
public static class ErrorResponses
{
    public static IServiceCollection AddGostioValidationErrors(this IServiceCollection services) =>
        services.Configure<ApiBehaviorOptions>(options =>
            options.InvalidModelStateResponseFactory = context => new BadRequestObjectResult(
                new ErrorResponse
                {
                    Status = StatusCodes.Status400BadRequest,
                    Message = ValidationException.DefaultMessage,
                    Errors = context.ModelState
                        .Where(entry => entry.Value is not null && entry.Value.Errors.Count > 0)
                        .ToDictionary(
                            entry => entry.Key,
                            entry => entry.Value!.Errors
                                .Select(error => error.ErrorMessage)
                                .ToArray()),
                    TraceId = context.HttpContext.TraceIdentifier,
                }));

    public static IApplicationBuilder UseGostioStatusCodeErrors(this IApplicationBuilder app) =>
        app.UseStatusCodePages(async context =>
        {
            var response = context.HttpContext.Response;

            await response.WriteAsJsonAsync(new ErrorResponse
            {
                Status = response.StatusCode,
                Message = MessageFor(response.StatusCode),
                TraceId = context.HttpContext.TraceIdentifier,
            });
        });

    private static string MessageFor(int statusCode) => statusCode switch
    {
        StatusCodes.Status401Unauthorized => "This request needs a signed in user.",
        StatusCodes.Status403Forbidden => "This account may not perform that action.",
        StatusCodes.Status404NotFound => "No resource matches this address.",
        StatusCodes.Status405MethodNotAllowed => "That method is not allowed on this address.",
        _ => "The request could not be completed.",
    };
}
