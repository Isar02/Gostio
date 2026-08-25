using Gostio.Model.Messaging;
using Gostio.Services.Configuration;

namespace Gostio.Services.Authentication;

internal static class PasswordResetEmail
{
    public static EmailMessage For(
        string firstName,
        string address,
        string token,
        ApiSettings api) =>
        new()
        {
            ToEmail = address,
            ToName = firstName,
            Subject = "Reset your Gostio password",
            Body = $"""
                Hello {firstName},

                Somebody asked to reset the password on the Gostio account registered to this
                address. Open {api.BaseUrl} and enter the code below to choose a new one.

                    {token}

                The code works once and stops working in {Hours} hours. If this was not you,
                nothing has changed and there is nothing to do.

                Gostio
                """,
        };

    private static int Hours => (int)ResetTokens.Lifetime.TotalHours;
}
