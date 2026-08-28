using System.Reflection;
using Gostio.API.Middleware;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.Tests.Architecture;

// Anonymous access is granted one endpoint at a time and taken back by nobody,
// so the whole surface is written down here rather than counted by hand.
public class AnonymousSurfaceTests
{
    private static readonly string[] Reachable =
    [
        "AuthController.ForgotPassword",
        "AuthController.Login",
        "AuthController.Register",
        "AuthController.ResetPassword",
        "PaymentWebhookController.Receive",
    ];

    [Fact]
    public void OnlyTheEndpointsWrittenDownHereAnswerWithoutSigningIn()
    {
        Assert.Equal(Reachable, AnonymousIn(typeof(ExceptionHandlingMiddleware).Assembly));
    }

    private static IReadOnlyList<string> AnonymousIn(Assembly assembly) =>
        [.. assembly.GetTypes()
            .Where(type => typeof(ControllerBase).IsAssignableFrom(type) && !type.IsAbstract)
            .SelectMany(controller => Actions(controller)
                .Where(action => IsAnonymous(controller, action))
                .Select(action => $"{controller.Name}.{action.Name}"))
            .Order()];

    // Inherited actions are read as well, and named for the controller that
    // answers on them rather than the base they were written in. What the
    // framework's own base class carries is not an endpoint and is left out.
    private static IEnumerable<MethodInfo> Actions(Type controller) =>
        controller
            .GetMethods(BindingFlags.Public | BindingFlags.Instance)
            .Where(action =>
                !action.IsSpecialName
                && action.DeclaringType?.Assembly == controller.Assembly);

    private static bool IsAnonymous(Type controller, MethodInfo action) =>
        action.GetCustomAttribute<AllowAnonymousAttribute>() is not null
        || controller.GetCustomAttribute<AllowAnonymousAttribute>() is not null;
}
