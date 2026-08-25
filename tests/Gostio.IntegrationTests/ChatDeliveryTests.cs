using Gostio.Model.Authorization;

namespace Gostio.IntegrationTests;

[Collection(DatabaseCollection.Name)]
public class ChatDeliveryTests(DatabaseFixture fixture)
{
    private readonly ConversationWorkspace workspace = new(fixture);

    [Fact]
    public async Task TheHubAsksTheQuestionTheEndpointsAnswer()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var stranger = await workspace.AGuestAsync();
        var thread = await workspace.ADirectThreadAsync(guest, host);

        Assert.True(await workspace.ReachesAsync(guest, false, thread));
        Assert.True(await workspace.ReachesAsync(host, false, thread));
        Assert.False(await workspace.ReachesAsync(stranger, false, thread));
    }

    [Fact]
    public async Task AnAdministratorReachesASupportThreadAndNoOtherKind()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var administrator = await workspace.AnAdministratorAsync();
        var direct = await workspace.ADirectThreadAsync(guest, host);
        var support = await workspace.ASupportThreadAsync(guest);

        Assert.True(await workspace.ReachesAsync(administrator, true, support));
        Assert.False(await workspace.ReachesAsync(administrator, true, direct));
        Assert.False(await workspace.ReachesAsync(administrator, false, support));
    }

    [Fact]
    public async Task AWrittenMessageIsHandedOverExactlyAsItWasAnswered()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var thread = await workspace.ADirectThreadAsync(guest, host);

        var delivered = await workspace.DeliveredBySendingAsync(
            guest, RoleNames.Guest, thread, "Are we still on for Friday?");

        var message = Assert.Single(delivered);

        Assert.Equal(thread, message.ConversationId);
        Assert.Equal(guest, message.SenderUserId);
        Assert.Equal("Are we still on for Friday?", message.Body);
        Assert.NotEqual(0, message.Id);
    }

    [Fact]
    public async Task AMessageNobodyMayWriteIsDeliveredToNobody()
    {
        var guest = await workspace.AGuestAsync();
        var host = await workspace.AHostAsync();
        var stranger = await workspace.AGuestAsync();
        var thread = await workspace.ADirectThreadAsync(guest, host);

        var delivered = await workspace.DeliveredBySendingAsync(
            stranger, RoleNames.Guest, thread, "Let me in.");

        Assert.Empty(delivered);
    }
}
