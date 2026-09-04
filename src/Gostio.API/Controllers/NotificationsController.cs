using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Services.Notifications;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/notifications")]
[Authorize]
public sealed class NotificationsController(
    INotificationService notifications,
    IDeviceTokenService devices) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<NotificationResponse>> Search(
        [FromQuery] NotificationSearchRequest search,
        CancellationToken cancellationToken) =>
        notifications.SearchAsync(search, cancellationToken);

    // Polled, so it costs a count rather than a page of rows.
    [HttpGet("unread-count")]
    public Task<UnreadCountResponse> Unread(CancellationToken cancellationToken) =>
        notifications.UnreadAsync(cancellationToken);

    [HttpPost("{id:int}/read")]
    public Task<NotificationResponse> MarkRead(int id, CancellationToken cancellationToken) =>
        notifications.MarkReadAsync(id, cancellationToken);

    [HttpPost("read")]
    public Task<UnreadCountResponse> MarkAllRead(CancellationToken cancellationToken) =>
        notifications.MarkAllReadAsync(cancellationToken);

    // Registered after signing in and removed on the way out. Neither call
    // takes an account id: a notice's owner comes off the token.
    [HttpPost("device-tokens")]
    public async Task<IActionResult> RegisterDevice(
        DeviceTokenRequest request,
        CancellationToken cancellationToken)
    {
        await devices.RegisterAsync(request, cancellationToken);

        return NoContent();
    }

    // The token travels in the body rather than in the path, so it stays out of
    // the places a URL is written down.
    [HttpDelete("device-tokens")]
    public async Task<IActionResult> ForgetDevice(
        [FromBody] DeviceTokenRequest request,
        CancellationToken cancellationToken)
    {
        await devices.ForgetAsync(request, cancellationToken);

        return NoContent();
    }
}
