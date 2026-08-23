namespace Gostio.Services.Database.Entities;

public interface IListing : IEntity
{
    int HostId { get; set; }

    bool IsActive { get; set; }
}
