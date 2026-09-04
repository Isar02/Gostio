using Gostio.Model.Requests;

namespace Gostio.Services.Notifications;

public interface IDeviceTokenService
{
    Task RegisterAsync(DeviceTokenRequest request, CancellationToken cancellationToken);

    Task ForgetAsync(DeviceTokenRequest request, CancellationToken cancellationToken);
}
