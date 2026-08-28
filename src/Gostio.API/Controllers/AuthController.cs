using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/auth")]
[Authorize]
public sealed class AuthController(IAuthService auth) : ControllerBase
{
    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(
        LoginRequest request,
        CancellationToken cancellationToken) =>
        await auth.LoginAsync(request, cancellationToken);

    [AllowAnonymous]
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(
        RegisterRequest request,
        CancellationToken cancellationToken) =>
        await auth.RegisterAsync(request, cancellationToken);

    [HttpGet("me")]
    public async Task<ActionResult<UserResponse>> Me(CancellationToken cancellationToken) =>
        await auth.GetCurrentUserAsync(cancellationToken);

    [HttpPost("change-password")]
    public async Task<ActionResult<AuthResponse>> ChangePassword(
        ChangePasswordRequest request,
        CancellationToken cancellationToken) =>
        await auth.ChangePasswordAsync(request, cancellationToken);

    [HttpPost("logout")]
    public async Task<IActionResult> Logout(CancellationToken cancellationToken)
    {
        await auth.LogoutAsync(cancellationToken);

        return NoContent();
    }

    // Accepted rather than a 404 or an OK carrying a hint: the same answer
    // whether or not the address belongs to an account.
    [AllowAnonymous]
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(
        ForgotPasswordRequest request,
        CancellationToken cancellationToken)
    {
        await auth.ForgotPasswordAsync(request, cancellationToken);

        return Accepted();
    }

    [AllowAnonymous]
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(
        ResetPasswordRequest request,
        CancellationToken cancellationToken)
    {
        await auth.ResetPasswordAsync(request, cancellationToken);

        return NoContent();
    }
}
