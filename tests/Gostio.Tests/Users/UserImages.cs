using System.Net.Http.Headers;
using Gostio.Model.Validation;

namespace Gostio.Tests.Users;

internal static class UserImages
{
    public static MultipartFormDataContent Form(bool withFile = true)
    {
        var form = new MultipartFormDataContent();

        if (withFile)
        {
            var file = new ByteArrayContent(StubUsers.Bytes);

            file.Headers.ContentType = new MediaTypeHeaderValue(ImageRules.Jpeg);

            form.Add(file, "File", "profile.jpg");
        }

        return form;
    }
}
