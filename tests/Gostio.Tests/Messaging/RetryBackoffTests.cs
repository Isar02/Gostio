using Gostio.Services.Messaging;

namespace Gostio.Tests.Messaging;

public class RetryBackoffTests
{
    [Fact]
    public void EachWaitIsTwiceTheOneBeforeIt() =>
        Assert.Equal(
            [TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(4),
                TimeSpan.FromSeconds(8)],
            Enumerable.Range(1, RetryBackoff.Attempts - 1).Select(RetryBackoff.After));

    // The last attempt is not waited on, because there is nothing after it.
    [Theory]
    [InlineData(0)]
    [InlineData(RetryBackoff.Attempts)]
    public void AnAttemptOutsideTheLadderIsRefused(int attempt) =>
        Assert.Throws<ArgumentOutOfRangeException>(() => RetryBackoff.After(attempt));

    [Fact]
    public void AListenerClimbsTheSameLadderAsAMessage() =>
        Assert.All(
            Enumerable.Range(1, RetryBackoff.Attempts - 1),
            attempt => Assert.Equal(
                RetryBackoff.After(attempt), RetryBackoff.Reopening(attempt)));

    [Fact]
    public void AListenerThatKeepsFailingStaysOnTheLongestWait() =>
        Assert.All(
            new[] { RetryBackoff.Attempts, 20, 4000 },
            attempt => Assert.Equal(
                RetryBackoff.After(RetryBackoff.Attempts - 1), RetryBackoff.Reopening(attempt)));
}
