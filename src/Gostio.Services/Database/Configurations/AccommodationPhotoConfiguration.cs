using Gostio.Model.Validation;
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
            .Property(photo => photo.ContentType)
            .IsRequired()
            .HasMaxLength(ColumnLengths.ContentType);

        builder
            .HasOne(photo => photo.Accommodation)
            .WithMany(accommodation => accommodation.Photos)
            .HasForeignKey(photo => photo.AccommodationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(photo => new { photo.AccommodationId, photo.DisplayOrder });

        builder
            .HasIndex(photo => photo.AccommodationId)
            .IsUnique()
            .HasFilter($"[{nameof(AccommodationPhoto.IsCover)}] = 1");
    }
}
