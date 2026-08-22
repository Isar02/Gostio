using System.ComponentModel.DataAnnotations;
using System.Text;
using Gostio.Model.Requests;

namespace Gostio.Tests.Validation;

public class PasswordLengthTests
{
    private const char Accented = 'é';

    private const string AcceptablePassword = "a-new-password";

    [Fact]
    public void SeventyTwoAsciiCharactersAreAccepted()
    {
        Assert.Empty(ValidateNew(new string('a', 72)));
    }

    [Fact]
    public void SeventyThreeAsciiCharactersAreRefused()
    {
        Assert.NotEmpty(ValidateNew(new string('a', 73)));
    }

    [Fact]
    public void SeventyTwoAccentedCharactersAreRefusedForTheBytesTheyCost()
    {
        var password = new string(Accented, 72);

        Assert.Equal(72, password.Length);
        Assert.Equal(144, Encoding.UTF8.GetByteCount(password));
        Assert.NotEmpty(ValidateNew(password));
    }

    [Fact]
    public void TheRefusalNamesTheFieldItIsAbout()
    {
        var failure = Assert.Single(ValidateNew(new string(Accented, 72)));

        Assert.Equal(
            nameof(ChangePasswordRequest.NewPassword),
            Assert.Single(failure.MemberNames));

        Assert.Contains(nameof(ChangePasswordRequest.NewPassword), failure.ErrorMessage);
    }

    // The password that is only checked against a hash is bounded the same
    // way as the one being stored: without this a password of exactly the
    // maximum verifies against itself followed by anything at all.
    [Fact]
    public void TheCurrentPasswordIsBoundedByTheSameBytes()
    {
        Assert.Empty(ValidateCurrent(new string('a', 72)));

        var failure = Assert.Single(ValidateCurrent(new string(Accented, 72)));

        Assert.Equal(
            nameof(ChangePasswordRequest.CurrentPassword),
            Assert.Single(failure.MemberNames));
    }

    [Fact]
    public void TheSubmittedPasswordIsBoundedByTheSameBytes()
    {
        Assert.Empty(ValidateSignIn(new string('a', 72)));

        var failure = Assert.Single(ValidateSignIn(new string(Accented, 72)));

        Assert.Equal(nameof(LoginRequest.Password), Assert.Single(failure.MemberNames));
    }

    // The seeded accounts were given a password shorter than a new one may be,
    // so a floor on either of these two fields locks all five of them out.
    [Fact]
    public void NeitherVerifiedPasswordHasAFloor()
    {
        Assert.Empty(ValidateSignIn("four"));
        Assert.Empty(ValidateCurrent("four"));
    }

    private static IReadOnlyList<ValidationResult> ValidateNew(string newPassword) =>
        Failures(new ChangePasswordRequest
        {
            CurrentPassword = AcceptablePassword,
            NewPassword = newPassword,
            ConfirmNewPassword = newPassword,
        });

    private static IReadOnlyList<ValidationResult> ValidateCurrent(string currentPassword) =>
        Failures(new ChangePasswordRequest
        {
            CurrentPassword = currentPassword,
            NewPassword = AcceptablePassword,
            ConfirmNewPassword = AcceptablePassword,
        });

    private static IReadOnlyList<ValidationResult> ValidateSignIn(string password) =>
        Failures(new LoginRequest { Username = "administrator", Password = password });

    private static IReadOnlyList<ValidationResult> Failures(object request)
    {
        var failures = new List<ValidationResult>();

        Validator.TryValidateObject(
            request, new ValidationContext(request), failures, validateAllProperties: true);

        return failures;
    }
}
