namespace Gostio.Services.Database.Entities;

public interface IListing : IEntity
{
    int HostId { get; set; }

    string Title { get; set; }

    // Both listings are somewhere, and the free-text search reads the place as
    // well as the name, so the city is part of what a listing is here.
    City City { get; set; }

    bool IsActive { get; set; }
}
