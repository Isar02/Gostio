using Gostio.Model.Enums;

namespace Gostio.Model.Requests;

public sealed class DeviceTokenRequest
{
    public string? Token { get; set; }

    public DevicePlatform? Platform { get; set; }
}
