using Gostio.Model.Messaging;

namespace Gostio.Services.Authentication;

internal static class PasswordResetEmail
{
    public static EmailMessage For(string firstName, string address, string token) =>
        new()
        {
            ToEmail = address,
            ToName = firstName,
            Subject = "Reset your Gostio password",
            Body = $"""
                Hello {firstName},

                Somebody asked to reset the password on the Gostio account registered to this
                address. Open Gostio, ask to reset the password again, and enter the code below
                on the screen that asks for it to choose a new one.

                    {token}

                The code works once and stops working in {Hours} hours. If this was not you,
                nothing has changed and there is nothing to do.

                Gostio
                """,
        };

    private static int Hours => (int)ResetTokens.Lifetime.TotalHours;
}
