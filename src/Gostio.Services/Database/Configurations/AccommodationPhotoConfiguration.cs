using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class AccommodationPhotoConfiguration : IEntityTypeConfiguration<AccommodationPhoto>
{
    public void Configure(EntityTypeBuilder<AccommodationPhoto> builder)
    {
        builder.HasKey(photo => photo.Id);

        builder
            .Property(photo => photo.Image)
            .IsRequired();

        builder
            .HasOne(photo => photo.Accommodation)
            .WithMany(accommodation => accommodation.Photos)
            .HasForeignKey(photo => photo.AccommodationId)
            .OnDelete(DeleteBehavior.Cascade);

        // The gallery reads in this order. DisplayOrder is deliberately not
        // unique, because swapping two photos would then need a spare value.
        builder.HasIndex(photo => new { photo.AccommodationId, photo.DisplayOrder });

        // At most one cover per listing.
        builder
            .HasIndex(photo => photo.AccommodationId)
            .IsUnique()
            .HasFilter($"[{nameof(AccommodationPhoto.IsCover)}] = 1");
    }
}
