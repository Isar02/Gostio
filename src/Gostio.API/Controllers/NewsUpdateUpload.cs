using Gostio.Model.Requests;

namespace Gostio.API.Controllers;

public sealed class NewsUpdateUpload : NewsUpsertRequest
{
    public IFormFile? File { get; set; }
}
