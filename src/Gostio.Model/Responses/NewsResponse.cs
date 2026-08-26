namespace Gostio.Model.Responses;

public sealed class NewsResponse : IIdentified
{
    public required int Id { get; init; }

    public required string Title { get; init; }

    public required string Body { get; init; }

    public required string ImageContentType { get; init; }

    public required int AuthorId { get; init; }

    public required string AuthorName { get; init; }

    public required DateTime PublishedAt { get; init; }

    public DateTime? ModifiedAt { get; init; }
}
