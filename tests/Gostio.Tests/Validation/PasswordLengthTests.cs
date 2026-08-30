using System.ComponentModel.DataAnnotations;
using System.Text;
using Gostio.Model.Requests;

namespace Gostio.Tests.Validation;

public class PasswordLengthTests
{
    private const char Accented = 'é';

    private const string AcceptablePassword = "a-new-password";

    private const string Mistyped = AcceptablePassword + "-typed-wrong";

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

    // The administrator's route carries no current password, so the two checks
    // that survive without one are proved on its own shape rather than inferred
    // from the shape it borrows them from.
    [Fact]
    public void TheAdministratorsNewPasswordIsBoundedByTheSameBytes()
    {
        Assert.Empty(ValidateSet(new string('a', 72)));

        var failure = Assert.Single(ValidateSet(new string(Accented, 72)));

        Assert.Equal(nameof(NewPasswordRequest.NewPassword), Assert.Single(failure.MemberNames));
    }

    // The pair sits on the base type and all three paths inherit it, so the
    // check that guards a typo is proved on each of the three shapes rather
    // than on the one that declares it.
    [Fact]
    public void EveryPathRefusesAConfirmationThatDoesNotMatch() =>
        Assert.All(Mismatched(), request =>
        {
            var failure = Assert.Single(Failures(request));

            Assert.Equal(
                nameof(NewPasswordRequest.ConfirmNewPassword),
                Assert.Single(failure.MemberNames));
        });

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

    private static IReadOnlyList<NewPasswordRequest> Mismatched() =>
    [
        new NewPasswordRequest
        {
            NewPassword = AcceptablePassword,
            ConfirmNewPassword = Mistyped,
        },
        new ChangePasswordRequest
        {
            CurrentPassword = AcceptablePassword,
            NewPassword = AcceptablePassword,
            ConfirmNewPassword = Mistyped,
        },
        new ResetPasswordRequest
        {
            Token = "a-token-from-a-link",
            NewPassword = AcceptablePassword,
            ConfirmNewPassword = Mistyped,
        },
    ];

    private static IReadOnlyList<ValidationResult> ValidateSet(string newPassword) =>
        Failures(new NewPasswordRequest
        {
            NewPassword = newPassword,
            ConfirmNewPassword = newPassword,
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
