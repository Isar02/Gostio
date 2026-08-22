using Gostio.Services.Authentication;

namespace Gostio.Tests.Authentication;

public class PasswordHasherTests
{
    [Fact]
    public void APasswordVerifiesAgainstItsOwnHashAndNothingElse()
    {
        var hash = PasswordHasher.Hash("a-password-worth-keeping");

        Assert.True(PasswordHasher.Verify("a-password-worth-keeping", hash));
        Assert.False(PasswordHasher.Verify("a-password-worth-keeping ", hash));
        Assert.False(PasswordHasher.Verify("something-else", hash));
    }

    [Fact]
    public void TheSamePasswordHashesDifferentlyEveryTime()
    {
        Assert.NotEqual(PasswordHasher.Hash("repeated"), PasswordHasher.Hash("repeated"));
    }

    // The seed and the login path have to produce one format, and the prefix is
    // where a changed algorithm or work factor would show first.
    [Fact]
    public void TheHashSaysWhichAlgorithmAndWorkFactorMadeIt()
    {
        Assert.StartsWith("$2a$11$", PasswordHasher.Hash("anything"));
    }
}
