using System.Text;
using Gostio.Model.Enums;
using Gostio.Model.Messaging;
using Gostio.Services.Configuration;
using Gostio.Services.Messaging;
using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Tests.Messaging;

public class PushSenderTests
{
    // Dropped where it is read rather than retried five times: no service
    // account is a deployment problem, and no amount of waiting fixes it.
    [Fact]
    public async Task APushCannotBeSentBeforeTheServiceAccountIsConfigured()
    {
        await using var provider = Consumers(new PushSettings { ServiceAccount = "" });

        var failure = await Assert.ThrowsAsync<PermanentMessageFailure>(() =>
            provider.GetRequiredService<IPushSender>().SendAsync("a-device", Anything(), default));

        Assert.Contains(
            "FIREBASE_SERVICE_ACCOUNT_BASE64", failure.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task AServiceAccountMissingWhatItNeedsIsRefusedTheSameWay()
    {
        await using var provider = Consumers(new PushSettings
        {
            ServiceAccount = Convert.ToBase64String(Encoding.UTF8.GetBytes("{}")),
        });

        await Assert.ThrowsAsync<PermanentMessageFailure>(() =>
            provider.GetRequiredService<IPushSender>().SendAsync("a-device", Anything(), default));
    }

    [Fact]
    public void AnEmptyServiceAccountIsNotOne()
    {
        Assert.False(new PushSettings { ServiceAccount = "" }.IsConfigured);
        Assert.False(new PushSettings { ServiceAccount = "   " }.IsConfigured);
        Assert.True(new PushSettings { ServiceAccount = "eyJ9" }.IsConfigured);
    }

    // A 404 says the device is gone and a 404 says the project is wrong. Only
    // the first may take a registration with it.
    [Theory]
    [InlineData(
        """{"error":{"code":404,"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}""",
        true)]
    [InlineData(
        """{"error":{"code":404,"status":"NOT_FOUND","message":"No such entity."}}""",
        false)]
    [InlineData(
        """{"error":{"code":403,"details":[{"errorCode":"SENDER_ID_MISMATCH"}]}}""",
        false)]
    [InlineData("""{"error":{"details":"UNREGISTERED"}}""", false)]
    [InlineData("UNREGISTERED", false)]
    [InlineData("", false)]
    public void OnlyTheServicesOwnWordSaysADeviceIsGone(string body, bool expected) =>
        Assert.Equal(expected, FcmError.Says(FcmError.Unregistered, body));
    private static ServiceProvider Consumers(PushSettings push)
    {
        var services = new ServiceCollection();

        services.AddLogging();
        services.AddSingleton(push);
        services.AddGostioMessageConsumers();

        return services.BuildServiceProvider();
    }

    private static PushMessage Anything() => new()
    {
        UserId = 1,
        Type = NotificationType.ReservationCreated,
        ReservationId = 2,
        Title = "Your booking is held",
        Body = "The host has 24 hours to confirm it.",
    };
}
