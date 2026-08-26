namespace Gostio.Services.Database.Entities;

public class NewsItem
{
    public int Id { get; set; }

    public int CreatedByUserId { get; set; }

    public User CreatedByUser { get; set; } = null!;

    public string Title { get; set; } = null!;

    public string Body { get; set; } = null!;

    public byte[] Image { get; set; } = null!;

    public string ImageContentType { get; set; } = null!;

    public DateTime PublishedAt { get; set; }

    public DateTime? ModifiedAt { get; set; }
}
