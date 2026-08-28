using System.ComponentModel.DataAnnotations;
using Gostio.Model.Requests;
using Gostio.Model.Validation;

namespace Gostio.Tests.Validation;

public class PhoneNumberFormatTests
{
    [Theory]
    [InlineData("+38761234567")]
    [InlineData("+387 61 234 567")]
    [InlineData("+387-61-234-567")]
    [InlineData("+387 (61) 234 567")]
    [InlineData("+491701234567")]
    [InlineData("061234567")]
    [InlineData("061 234 567")]
    [InlineData("033 123 456")]
    public void ANumberInEitherShapeIsAccepted(string number)
    {
        Assert.Empty(Validate(number));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void AnAbsentNumberIsStillValid(string? number)
    {
        Assert.Empty(Validate(number));
    }

    [Theory]
    [InlineData("61234567")]
    [InlineData("+387")]
    [InlineData("+0387123456")]
    [InlineData("061 234 56")]
    [InlineData("0612345678")]
    [InlineData("+3876123456789012")]
    [InlineData("061-CALL-ME")]
    public void AnythingElseIsRefused(string number)
    {
        Assert.NotEmpty(Validate(number));
    }

    [Fact]
    public void AForeignNumberWithoutItsCodeIsRefused()
    {
        Assert.NotEmpty(Validate("01701234567"));
    }

    [Fact]
    public void TheRefusalSaysWhatToTypeInstead()
    {
        var failure = Assert.Single(Validate("01701234567"));

        Assert.Equal(PhoneNumbers.Message, failure.ErrorMessage);
    }

    [Theory]
    [InlineData("061 234 567", "+38761234567")]
    [InlineData("033-123-456", "+38733123456")]
    [InlineData("+387 61 234 567", "+38761234567")]
    [InlineData("+49 (170) 1234567", "+491701234567")]
    public void ANumberIsStoredInOneShapeHoweverItWasTyped(string typed, string stored)
    {
        Assert.Equal(stored, PhoneNumbers.Normalise(typed));
    }

    [Fact]
    public void TwoRecordsOfOneNumberComeOutEqual()
    {
        Assert.Equal(
            PhoneNumbers.Normalise("061 234 567"),
            PhoneNumbers.Normalise("+387-61-234-567"));
    }

    [Fact]
    public void NothingTypedIsNothingStored()
    {
        Assert.Null(PhoneNumbers.Normalise("   "));
    }

    private static List<ValidationResult> Validate(string? number)
    {
        var request = new UserUpdateRequest
        {
            FirstName = "Amina",
            LastName = "Hodzic",
            Email = "amina@example.com",
            PhoneNumber = number,
        };

        var failures = new List<ValidationResult>();

        Validator.TryValidateObject(
            request, new ValidationContext(request), failures, validateAllProperties: true);

        return [.. failures.Where(failure =>
            failure.MemberNames.Contains(nameof(UserUpdateRequest.PhoneNumber)))];
    }
}
