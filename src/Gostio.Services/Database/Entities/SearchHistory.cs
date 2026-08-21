using Gostio.Model.Enums;

namespace Gostio.Services.Database.Entities;

public class SearchHistory
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public User User { get; set; } = null!;

    public SearchTarget Target { get; set; }

    public string? Term { get; set; }

    public int? CityId { get; set; }

    public City? City { get; set; }

    public int? GuestCount { get; set; }

    public decimal? MinPrice { get; set; }

    public decimal? MaxPrice { get; set; }

    public DateTime SearchedAt { get; set; }
}
