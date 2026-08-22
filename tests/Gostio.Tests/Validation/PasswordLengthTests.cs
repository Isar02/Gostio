using System.ComponentModel.DataAnnotations;
using System.Text;
using Gostio.Model.Requests;

namespace Gostio.Tests.Validation;

public class PasswordLengthTests
{
    private const char Accented = 'é';

    [Fact]
    public void SeventyTwoAsciiCharactersAreAccepted()
    {
        Assert.Empty(Validate(new string('a', 72)));
    }

    [Fact]
    public void SeventyThreeAsciiCharactersAreRefused()
    {
        Assert.NotEmpty(Validate(new string('a', 73)));
    }

    [Fact]
    public void SeventyTwoAccentedCharactersAreRefusedForTheBytesTheyCost()
    {
        var password = new string(Accented, 72);

        Assert.Equal(72, password.Length);
        Assert.Equal(144, Encoding.UTF8.GetByteCount(password));
        Assert.NotEmpty(Validate(password));
    }

    [Fact]
    public void TheRefusalNamesTheFieldItIsAbout()
    {
        var failure = Assert.Single(Validate(new string(Accented, 72)));

        Assert.Equal(
            nameof(ChangePasswordRequest.NewPassword),
            Assert.Single(failure.MemberNames));

        Assert.Contains(nameof(ChangePasswordRequest.NewPassword), failure.ErrorMessage);
    }

    private static IReadOnlyList<ValidationResult> Validate(string newPassword)
    {
        var request = new ChangePasswordRequest
        {
            CurrentPassword = "the-current-one",
            NewPassword = newPassword,
            ConfirmNewPassword = newPassword,
        };

        var failures = new List<ValidationResult>();

        Validator.TryValidateObject(
            request, new ValidationContext(request), failures, validateAllProperties: true);

        return failures;
    }
}
